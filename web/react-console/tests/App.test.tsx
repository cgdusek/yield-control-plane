import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { App } from '../src/App';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: false }
  }
});

test('renders the operational console and FIDD boundary', () => {
  render(
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  );
  expect(screen.getByText('Institutional Yield Control Plane')).toBeInTheDocument();
  expect(screen.getByText(/FIDD is modeled as a payment and stablecoin cash rail/)).toBeInTheDocument();
});
