import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../utils/apiClient.js';

/**
 * useApiQuery — wraps useQuery with the shared api.get client.
 *
 * @param {string|string[]} queryKey  - TanStack query key
 * @param {string} url                - API endpoint
 * @param {object} [options]          - extra useQuery options
 */
export function useApiQuery(queryKey, url, options = {}) {
  return useQuery({
    queryKey: Array.isArray(queryKey) ? queryKey : [queryKey],
    queryFn: () => api.get(url),
    ...options,
  });
}

/**
 * useApiMutation — wraps useMutation with the shared api client.
 *
 * @param {Function} mutationFn       - async fn that returns a promise
 * @param {object}   [options]        - extra useMutation options (onSuccess, invalidates, etc.)
 * @param {string[]} [options.invalidates] - query keys to invalidate on success
 */
export function useApiMutation(mutationFn, { invalidates = [], ...options } = {}) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: (...args) => {
      for (const key of invalidates) {
        queryClient.invalidateQueries({ queryKey: Array.isArray(key) ? key : [key] });
      }
      options.onSuccess?.(...args);
    },
    ...options,
  });
}
