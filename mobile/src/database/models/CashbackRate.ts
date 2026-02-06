import { Model } from '@nozbe/watermelondb';
import { field, date, readonly, relation } from '@nozbe/watermelondb/decorators';
import type { Associations } from '@nozbe/watermelondb/Model';
import type BankCard from './BankCard';

export default class CashbackRate extends Model {
  static table = 'cashback_rates';

  static associations: Associations = {
    bank_cards: { type: 'belongs_to', key: 'bank_card_id' },
  };

  @field('bank_card_id') bankCardId!: string;
  @field('mcc_code') mccCode!: string;
  @field('category_name_ru') categoryNameRu!: string;
  @field('category_name_en') categoryNameEn?: string;
  @field('cashback_percent') cashbackPercent!: number;
  @date('valid_from') validFrom!: Date;
  @date('valid_until') validUntil!: Date;
  @field('is_active') isActive!: boolean;

  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;

  @relation('bank_cards', 'bank_card_id') bankCard!: BankCard;
}
