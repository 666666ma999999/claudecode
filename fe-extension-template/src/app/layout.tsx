import { CoreProvider, Navigation } from '@/core';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        <CoreProvider>
          <Navigation />
          <main>{children}</main>
        </CoreProvider>
      </body>
    </html>
  );
}
