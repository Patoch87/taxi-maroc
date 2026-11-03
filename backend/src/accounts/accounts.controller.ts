import { Body, Controller, Get, Header, HttpCode, Post, Query } from '@nestjs/common';
import { AccountsService } from './accounts.service';

/** Lien de téléchargement donné à qui écrit sur WhatsApp sans avoir l'application. */
export const lienApplication = () =>
  process.env.BAB_LIEN_APP || 'https://github.com/Patoch87/taxi-maroc/releases/latest/download/taxi-maroc.apk';

@Controller()
export class AccountsController {
  constructor(private readonly comptes: AccountsService) {}

  /** Réglages publics lus par l'application au lancement. */
  @Get('config')
  config() {
    return {
      // Numéro WhatsApp public de Bab Taxi (chiffres, avec l'indicatif), pour le bouton « Commander sur WhatsApp ».
      whatsapp: (process.env.WHATSAPP_NUMERO_PUBLIC ?? '').replace(/\D/g, '') || null,
      sms: this.comptes.modeSms(),
      // Paiement par carte : seulement quand un vrai prestataire (CMI) sera branché.
      carte: process.env.BAB_PAIEMENT_CARTE === 'oui',
      lienApp: lienApplication(),
    };
  }

  /**
   * Bouton « Suivre mon taxi » de WhatsApp : ouvre l'application Bab Taxi (Android : lien intent, l'application
   * reprend d'elle-même la course en cours du passager) ; sans l'application, le téléchargement.
   */
  @Get('ouvrir')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  ouvrir(@Query('c') c?: string) {
    const course = (c ?? '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 40);
    const paquet = process.env.BAB_PAQUET_ANDROID || 'ma.taxi.taxi_maroc';
    const lien = lienApplication();
    const intent = `intent://course/${course}#Intent;scheme=babtaxi;package=${paquet};S.browser_fallback_url=${encodeURIComponent(lien)};end`;
    const web = process.env.BAB_LIEN_WEB || '';
    return PAGE_OUVRIR.replace(/__INTENT__/g, intent).replace(/__LIEN__/g, lien).replace(/__WEB__/g, web);
  }

  @Post('accounts')
  enregistrer(@Body() corps: Parameters<AccountsService['enregistrer']>[0]) {
    const c = this.comptes.enregistrer(corps);
    return { id: c.id, verifie: c.verifie };
  }

  @Post('auth/code')
  @HttpCode(200)
  code(@Body() corps: { phone?: string }) {
    return this.comptes.envoyerCode(corps?.phone ?? '');
  }

  @Post('auth/verify')
  @HttpCode(200)
  async verifier(@Body() corps: { phone?: string; code?: string }) {
    const ok = await this.comptes.verifierCode(corps?.phone ?? '', corps?.code ?? '');
    // Connexion à un compte existant (nouveau téléphone, application réinstallée) : le compte lié à ce
    // numéro est rendu seulement après le bon code.
    const c = ok ? this.comptes.parNumero(corps?.phone ?? '') : undefined;
    return {
      ok,
      compte: c && !c.bloque
        ? { id: c.id, telephone: c.telephone, prenom: c.prenom, nom: c.nom, email: c.email ?? '', nationalite: c.nationalite ?? '', langue: c.langue ?? '' }
        : null,
    };
  }
}

const PAGE_OUVRIR = `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Bab Taxi</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#f6efe2;color:#0f2a1e;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
main{padding:24px;max-width:360px}.porte{width:72px;height:96px;margin:0 auto 16px;border-radius:36px 36px 6px 6px;background:#c1272d;box-shadow:inset 0 0 0 8px #006233}
h1{font-size:22px;margin:0 0 8px}p{color:#5b6b62;margin:0 0 20px}a.btn{display:block;background:#006233;color:#fff;text-decoration:none;font-weight:700;padding:16px;border-radius:14px;font-size:18px}
a.sec{display:block;margin-top:14px;color:#006233;font-weight:600}</style></head>
<body><main><div class="porte"></div><h1>Votre taxi arrive</h1><p>Suivez votre course dans l’application Bab Taxi.<br>تبع الطاكسي ديالك فالتطبيق.</p>
<a class="btn" id="ouvrir" href="__INTENT__">Ouvrir Bab Taxi</a>
<a class="sec" href="__LIEN__">Installer l’application</a></main>
<script>
var android = /android/i.test(navigator.userAgent);
var web = '__WEB__';
if (!android) { var b = document.getElementById('ouvrir'); if (web) b.href = web; else b.style.display = 'none'; }
else setTimeout(function () { location.href = document.getElementById('ouvrir').href; }, 150);
</script></body></html>`;
