export const metadata = {
  title: 'Request',
  description: 'Find and compare prices. Request delivers.'
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: 'Inter, system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif' }}>
        {children}
      </body>
    </html>
  );
}
