import { Model } from '@nozbe/watermelondb';
import { field, date, readonly, children } from '@nozbe/watermelondb/decorators';
import type { Associations } from '@nozbe/watermelondb/Model';

export default class BankCard extends Model {
  static table = 'bank_cards';

  static associations: Associations = {
    cashback_rates: { type: 'has_many', foreignKey: 'bank_card_id' },
  };

  @field('bank_name') bankName!: string;
  @field('bank_logo_url') bankLogoUrl?: string;
  @field('last_four_digits') lastFourDigits!: string;
  @field('card_holder_name') cardHolderName?: string;
  @field('is_active') isActive!: boolean;

  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;

  @children('cashback_rates') cashbackRates!: any; // CashbackRate[]
}
