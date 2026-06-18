// Deno Global Shims for IDE type resolution in VS Code / Cursor without Deno CLI
declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
}

// Allow importing standard deno.land URLs
declare module "https://deno.land/std@0.177.0/http/server.ts" {
  export function serve(
    handler: (request: Request) => Response | Promise<Response>,
    options?: any
  ): void;
}

// Allow importing esm.sh Supabase library
declare module "https://esm.sh/@supabase/supabase-js@2" {
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: any
  ): any;
}

// Allow importing npm packages via npm: prefix
declare module "npm:google-auth-library" {
  export class JWT {
    constructor(options: {
      email: string;
      key: string;
      scopes: string[];
    });
    getAccessToken(): Promise<{ token: string | null }>;
  }
}
