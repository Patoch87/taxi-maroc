import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
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
    return { ok: await this.comptes.verifierCode(corps?.phone ?? '', corps?.code ?? '') };
  }
}
