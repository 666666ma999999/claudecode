import type { ApiClient, RequestOptions, AuthService } from '../types';

export function createApiClient(auth: AuthService, baseUrl = '/api'): ApiClient {
  async function request<T>(method: string, path: string, data?: unknown, options?: RequestOptions): Promise<T> {
    const url = new URL(`${baseUrl}${path}`, window.location.origin);
    if (options?.params) {
      Object.entries(options.params).forEach(([key, value]) => {
        url.searchParams.set(key, value);
      });
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...options?.headers,
    };

    const token = auth.getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(url.toString(), {
      method,
      headers,
      body: data !== undefined ? JSON.stringify(data) : undefined,
    });

    if (!response.ok) {
      throw new Error(`API Error: ${response.status} ${response.statusText}`);
    }

    return response.json() as Promise<T>;
  }

  return {
    get: <T>(path: string, options?: RequestOptions) => request<T>('GET', path, undefined, options),
    post: <T>(path: string, data?: unknown, options?: RequestOptions) => request<T>('POST', path, data, options),
    put: <T>(path: string, data?: unknown, options?: RequestOptions) => request<T>('PUT', path, data, options),
    delete: <T>(path: string, options?: RequestOptions) => request<T>('DELETE', path, undefined, options),
  };
}
