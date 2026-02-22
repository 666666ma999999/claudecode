import type { UserRecord } from '../types/user';

interface UserStore {
  users: UserRecord[];
  selectedUserId: string | null;
  setUsers: (users: UserRecord[]) => void;
  selectUser: (id: string | null) => void;
}

// Minimal store without external dependencies.
// In a real project, replace with Zustand or similar.
let state: UserStore = {
  users: [],
  selectedUserId: null,
  setUsers(users: UserRecord[]) {
    state = { ...state, users };
  },
  selectUser(id: string | null) {
    state = { ...state, selectedUserId: id };
  },
};

export function getUserStore(): UserStore {
  return state;
}
