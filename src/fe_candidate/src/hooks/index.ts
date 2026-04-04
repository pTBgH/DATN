import { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import api from '@/lib/api';

export const useFetch = <T,>(
    key: string[],
    fn: () => Promise<any>,
    options = {}
) => {
    return useQuery(key, fn, {
        staleTime: 1000 * 60 * 5,
        cacheTime: 1000 * 60 * 10,
        ...options,
    });
};

export const useMutate = <T, V>(
    fn: (data: V) => Promise<T>,
    options = {}
) => {
    const queryClient = useQueryClient();

    return useMutation(fn, {
        onSuccess: () => {
            queryClient.invalidateQueries();
        },
        ...options,
    });
};

export const useLocalStorage = <T,>(
    key: string,
    initialValue: T
): [T, (value: T | ((val: T) => T)) => void] => {
    const [storedValue, setStoredValue] = useState<T>(initialValue);

    useEffect(() => {
        if (typeof window === 'undefined') return;

        try {
            const item = window.localStorage.getItem(key);
            if (item) {
                setStoredValue(JSON.parse(item));
            }
        } catch (error) {
            console.error(error);
        }
    }, [key]);

    const setValue = (value: T | ((val: T) => T)) => {
        try {
            const valueToStore = value instanceof Function ? value(storedValue) : value;
            setStoredValue(valueToStore);
            if (typeof window !== 'undefined') {
                window.localStorage.setItem(key, JSON.stringify(valueToStore));
            }
        } catch (error) {
            console.error(error);
        }
    };

    return [storedValue, setValue];
};
