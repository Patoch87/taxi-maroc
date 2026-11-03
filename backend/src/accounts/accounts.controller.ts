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

  /** Android App Links : l'application Bab Taxi (signée avec la clé Bab) ouvre directement les liens /ouvrir. */
  @Get('.well-known/assetlinks.json')
  assetlinks() {
    const empreintes = (process.env.BAB_EMPREINTES_ANDROID || EMPREINTE_TEST)
      .split(',')
      .map((e) => e.trim())
      .filter(Boolean);
    return [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: { namespace: 'android_app', package_name: process.env.BAB_PAQUET_ANDROID || 'ma.taxi.taxi_maroc', sha256_cert_fingerprints: empreintes },
      },
    ];
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

/** Empreinte de la clé de signature Android (secret GitHub BAB_KEYSTORE_B64). */
const EMPREINTE_TEST = '19:45:54:5E:67:39:F6:61:4B:91:B5:A3:B1:42:41:8D:33:93:BC:8F:C9:C2:39:2E:99:2E:AE:20:99:A8:82:3E';

const PAGE_OUVRIR = `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Bab Taxi</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#f6efe2;color:#0f2a1e;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
main{padding:24px;max-width:360px}.porte{width:72px;height:96px;margin:0 auto 16px;border-radius:36px 36px 6px 6px;background:#c1272d;box-shadow:inset 0 0 0 8px #006233}
h1{font-size:22px;margin:0 0 8px}p{color:#5b6b62;margin:0 0 20px}a.btn{display:block;background:#006233;color:#fff;text-decoration:none;font-weight:700;padding:16px;border-radius:14px;font-size:18px}
a.sec{display:block;margin-top:14px;color:#006233;font-weight:600}</style></head>
<body><main><div class="porte"></div><h1>Installez Bab Taxi</h1><p>Votre taxi est en route : suivez-le dans l’application Bab Taxi.<br>الطاكسي ديالك جاي: تبعو فالتطبيق ديال باب طاكسي.</p>
<a class="btn" href="__LIEN__">Installer l’application</a>
<a class="sec" id="ouvrir" href="__INTENT__">J’ai déjà l’application : l’ouvrir</a></main>
<script>
var android = /android/i.test(navigator.userAgent);
var web = '__WEB__';
if (!android) { var b = document.getElementById('ouvrir'); if (web) b.href = web; else b.style.display = 'none'; }
else location.replace(document.getElementById('ouvrir').href);
</script></body></html>`;
