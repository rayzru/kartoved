import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class WidgetStats extends Model {
  static table = 'widget_stats';

  @field('total_uses') totalUses!: number;
  @field('estimated_savings_rub') estimatedSavingsRub!: number;
  @date('last_used_at') lastUsedAt!: Date;

  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;
}
