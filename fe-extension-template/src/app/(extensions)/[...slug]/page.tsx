import { ExtensionRouteResolver } from '@/core';

export default function ExtensionPage({ params }: { params: { slug: string[] } }) {
  return <ExtensionRouteResolver slug={params.slug} />;
}
