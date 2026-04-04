import { useQuery, useMutation, useQueryClient } from 'react-query';

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
