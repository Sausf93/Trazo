/**
 * Hook mínimo para cargar datos con estados de carga/error y cancelación.
 * `deps` controla cuándo se relanza. La función recibe un AbortSignal.
 */
import { useCallback, useEffect, useState } from "react";
import { ApiError } from "../api/client";

interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

export function useAsync<T>(
  fn: (signal: AbortSignal) => Promise<T>,
  deps: unknown[],
): AsyncState<T> & { reload: () => void } {
  const [state, setState] = useState<AsyncState<T>>({ data: null, loading: true, error: null });
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    const controller = new AbortController();
    setState((s) => ({ ...s, loading: true, error: null }));
    fn(controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) setState({ data, loading: false, error: null });
      })
      .catch((err: unknown) => {
        if (controller.signal.aborted || (err as Error)?.name === "AbortError") return;
        const msg = err instanceof ApiError ? err.message : "Ha ocurrido un error inesperado.";
        setState({ data: null, loading: false, error: msg });
      });
    return () => controller.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce]);

  return { ...state, reload };
}
