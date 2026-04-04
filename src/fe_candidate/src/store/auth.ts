import { create } from 'zustand';
import Cookie from 'js-cookie';

export interface User {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    avatar?: string;
    role: string;
}

export interface AuthState {
    user: User | null;
    token: string | null;
    isLoading: boolean;
    isAuthenticated: boolean;
    setUser: (user: User | null) => void;
    setToken: (token: string) => void;
    logout: () => void;
    hydrate: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
    user: null,
    token: null,
    isLoading: false,
    isAuthenticated: false,

    setUser: (user) => {
        set({ user, isAuthenticated: !!user });
    },

    setToken: (token) => {
        Cookie.set('access_token', token, { expires: 7, secure: true, sameSite: 'strict' });
        set({ token, isAuthenticated: true });
    },

    logout: () => {
        Cookie.remove('access_token');
        Cookie.remove('refresh_token');
        set({ user: null, token: null, isAuthenticated: false });
    },

    hydrate: () => {
        const token = Cookie.get('access_token');
        if (token) {
            set({ token, isAuthenticated: true });
        }
    },
}));
