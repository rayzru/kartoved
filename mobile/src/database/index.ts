import { Database } from '@nozbe/watermelondb';
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite';
import { schema } from './schema';
import { BankCard, CashbackRate, WirelessSignal, WidgetStats } from './models';

const adapter = new SQLiteAdapter({
  schema,
  // (Optional) DB name or file system path
  dbName: 'kartoved',
  // (Recommended) enable JSI mode
  jsi: true,
  // (Optional) handle migrations
  onSetUpError: (error) => {
    console.error('WatermelonDB setup error:', error);
  },
});

export const database = new Database({
  adapter,
  modelClasses: [BankCard, CashbackRate, WirelessSignal, WidgetStats],
});
