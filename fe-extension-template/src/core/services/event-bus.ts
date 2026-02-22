import type { EventBus, CoreEvents } from '../types';

type Handler<T = unknown> = (data: T) => void;

export function createEventBus(): EventBus {
  const listeners = new Map<string, Set<Handler>>();

  return {
    emit<K extends keyof CoreEvents>(event: K, data: CoreEvents[K]): void {
      const handlers = listeners.get(event as string);
      if (handlers) {
        handlers.forEach(handler => handler(data));
      }
    },

    on<K extends keyof CoreEvents>(event: K, handler: (data: CoreEvents[K]) => void): () => void {
      const key = event as string;
      if (!listeners.has(key)) {
        listeners.set(key, new Set());
      }
      listeners.get(key)!.add(handler as Handler);
      return () => {
        listeners.get(key)?.delete(handler as Handler);
      };
    },

    off<K extends keyof CoreEvents>(event: K, handler: (data: CoreEvents[K]) => void): void {
      listeners.get(event as string)?.delete(handler as Handler);
    },
  };
}
