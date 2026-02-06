import { create } from 'zustand';
import { database } from '../database';
import BankCard from '../database/models/BankCard';
import CashbackRate from '../database/models/CashbackRate';

interface CardsState {
  cards: BankCard[];
  selectedCardId: string | null;
  isLoading: boolean;

  // Actions
  loadCards: () => Promise<void>;
  addCard: (data: {
    bankName: string;
    lastFourDigits: string;
    cardHolderName?: string;
  }) => Promise<BankCard>;
  removeCard: (cardId: string) => Promise<void>;
  selectCard: (cardId: string | null) => void;
  updateCardCashback: (
    cardId: string,
    cashbackData: {
      mccCode: string;
      categoryNameRu: string;
      cashbackPercent: number;
      validFrom: Date;
      validUntil: Date;
    }
  ) => Promise<void>;
}

/**
 * Cards management store with Zustand + WatermelonDB
 */
export const useCardsStore = create<CardsState>((set, get) => ({
  cards: [],
  selectedCardId: null,
  isLoading: false,

  /**
   * Load all cards from WatermelonDB
   */
  loadCards: async () => {
    try {
      set({ isLoading: true });

      const cardsCollection = database.get<BankCard>('bank_cards');
      const cards = await cardsCollection.query().fetch();

      set({ cards, isLoading: false });
      console.log(`Loaded ${cards.length} cards`);
    } catch (error) {
      console.error('Failed to load cards:', error);
      set({ isLoading: false });
      throw error;
    }
  },

  /**
   * Add new bank card
   */
  addCard: async (data) => {
    try {
      set({ isLoading: true });

      // PCI COMPLIANCE: Validate last 4 digits only (CRITICAL SECURITY)
      if (!/^\d{4}$/.test(data.lastFourDigits)) {
        throw new Error(
          'Invalid card format: Only last 4 digits allowed (PCI-DSS compliance)'
        );
      }

      const card = await database.write(async () => {
        return await database.get<BankCard>('bank_cards').create((card) => {
          card.bankName = data.bankName;
          card.lastFourDigits = data.lastFourDigits;
          card.cardHolderName = data.cardHolderName;
          card.isActive = true;
        });
      });

      // Reload cards
      await get().loadCards();

      console.log('Card added successfully:', card.id);
      return card;
    } catch (error) {
      console.error('Failed to add card:', error);
      set({ isLoading: false });
      throw error;
    }
  },

  /**
   * Remove bank card
   */
  removeCard: async (cardId) => {
    try {
      set({ isLoading: true });

      await database.write(async () => {
        const card = await database.get<BankCard>('bank_cards').find(cardId);
        await card.markAsDeleted();
      });

      // Reload cards
      await get().loadCards();

      console.log('Card removed successfully:', cardId);
    } catch (error) {
      console.error('Failed to remove card:', error);
      set({ isLoading: false });
      throw error;
    }
  },

  /**
   * Select card for display/editing
   */
  selectCard: (cardId) => {
    set({ selectedCardId: cardId });
  },

  /**
   * Update cashback rate for a card
   */
  updateCardCashback: async (cardId, cashbackData) => {
    try {
      set({ isLoading: true });

      await database.write(async () => {
        await database.get<CashbackRate>('cashback_rates').create((rate) => {
          rate.bankCardId = cardId;
          rate.mccCode = cashbackData.mccCode;
          rate.categoryNameRu = cashbackData.categoryNameRu;
          rate.cashbackPercent = cashbackData.cashbackPercent;
          rate.validFrom = cashbackData.validFrom;
          rate.validUntil = cashbackData.validUntil;
          rate.isActive = true;
        });
      });

      set({ isLoading: false });
      console.log('Cashback rate updated for card:', cardId);
    } catch (error) {
      console.error('Failed to update cashback:', error);
      set({ isLoading: false });
      throw error;
    }
  },
}));
