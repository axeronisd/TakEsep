import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { createClient } from "@supabase/supabase-js";

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://smvegrscjnoelfsipwqq.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig';

const supabase = createClient(supabaseUrl, supabaseKey);

// Create MCP server
const server = new Server(
  {
    name: "takEsep-supabase-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "list_tables",
        description: "List all tables in the Supabase database",
        inputSchema: {
          type: "object",
          properties: {}
        }
      },
      {
        name: "describe_table",
        description: "Get the structure of a specific table including columns and types",
        inputSchema: {
          type: "object",
          properties: {
            tableName: {
              type: "string",
              description: "Name of the table to describe"
            }
          },
          required: ["tableName"]
        }
      },
      {
        name: "query_table",
        description: "Query a table with optional filters and limits",
        inputSchema: {
          type: "object",
          properties: {
            tableName: {
              type: "string",
              description: "Name of the table to query"
            },
            filters: {
              type: "object",
              description: "Key-value pairs for filtering (e.g., {company_id: 'xxx'})"
            },
            limit: {
              type: "number",
              description: "Maximum number of rows to return (default: 10)"
            },
            orderBy: {
              type: "string",
              description: "Column to order by"
            },
            ascending: {
              type: "boolean",
              description: "Sort order (default: true)"
            }
          },
          required: ["tableName"]
        }
      },
      {
        name: "get_table_count",
        description: "Get the total count of rows in a table",
        inputSchema: {
          type: "object",
          properties: {
            tableName: {
              type: "string",
              description: "Name of the table"
            },
            filters: {
              type: "object",
              description: "Optional filters"
            }
          },
          required: ["tableName"]
        }
      },
      {
        name: "search_tables",
        description: "Search for tables by name pattern",
        inputSchema: {
          type: "object",
          properties: {
            pattern: {
              type: "string",
              description: "Pattern to search for in table names"
            }
          },
          required: ["pattern"]
        }
      },
      {
        name: "get_recent_data",
        description: "Get recent records from a table ordered by created_at",
        inputSchema: {
          type: "object",
          properties: {
            tableName: {
              type: "string",
              description: "Name of the table"
            },
            limit: {
              type: "number",
              description: "Number of recent records (default: 5)"
            }
          },
          required: ["tableName"]
        }
      }
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "list_tables": {
        // Get list of tables using information_schema
        const { data, error } = await supabase
          .rpc('get_tables');

        if (error) {
          // Fallback: try common table names
          const commonTables = [
            'products', 'sales', 'arrivals', 'transfers', 'audits',
            'categories', 'warehouses', 'companies', 'employees',
            'clients', 'services', 'sale_items', 'audit_items',
            'arrival_items', 'transfer_items', 'write_offs'
          ];

          return {
            content: [
              {
                type: "text",
                text: JSON.stringify({
                  note: "Using fallback table list (RPC not available)",
                  tables: commonTables
                }, null, 2)
              }
            ]
          };
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(data, null, 2)
            }
          ]
        };
      }

      case "describe_table": {
        const { tableName } = args;

        // Try to get sample data to infer structure
        const { data, error } = await supabase
          .from(tableName)
          .select('*')
          .limit(1);

        if (error) {
          throw new Error(`Error querying table ${tableName}: ${error.message}`);
        }

        if (data && data.length > 0) {
          const columns = Object.keys(data[0]).map(key => ({
            name: key,
            type: typeof data[0][key],
            sample: data[0][key]
          }));

          return {
            content: [
              {
                type: "text",
                text: JSON.stringify({
                  table: tableName,
                  columns: columns,
                  sampleRow: data[0]
                }, null, 2)
              }
            ]
          };
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({
                table: tableName,
                note: "Table is empty or no access",
                columns: []
              }, null, 2)
            }
          ]
        };
      }

      case "query_table": {
        const { tableName, filters, limit = 10, orderBy, ascending = true } = args;

        let query = supabase.from(tableName).select('*');

        if (filters) {
          Object.keys(filters).forEach(key => {
            query = query.eq(key, filters[key]);
          });
        }

        if (orderBy) {
          query = query.order(orderBy, { ascending });
        }

        query = query.limit(limit);

        const { data, error } = await query;

        if (error) {
          throw new Error(`Error querying table ${tableName}: ${error.message}`);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({
                table: tableName,
                count: data.length,
                data: data
              }, null, 2)
            }
          ]
        };
      }

      case "get_table_count": {
        const { tableName, filters } = args;

        let query = supabase.from(tableName).select('*', { count: 'exact', head: true });

        if (filters) {
          Object.keys(filters).forEach(key => {
            query = query.eq(key, filters[key]);
          });
        }

        const { count, error } = await query;

        if (error) {
          throw new Error(`Error counting table ${tableName}: ${error.message}`);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({
                table: tableName,
                count: count
              }, null, 2)
            }
          ]
        };
      }

      case "search_tables": {
        const { pattern } = args;

        const commonTables = [
          'products', 'sales', 'arrivals', 'transfers', 'audits',
          'categories', 'warehouses', 'companies', 'employees',
          'clients', 'services', 'sale_items', 'audit_items',
          'arrival_items', 'transfer_items', 'write_offs'
        ];

        const matched = commonTables.filter(t =>
          t.toLowerCase().includes(pattern.toLowerCase())
        );

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({
                pattern: pattern,
                matchedTables: matched
              }, null, 2)
            }
          ]
        };
      }

      case "get_recent_data": {
        const { tableName, limit = 5 } = args;

        const { data, error } = await supabase
          .from(tableName)
          .select('*')
          .order('created_at', { ascending: false })
          .limit(limit);

        if (error) {
          throw new Error(`Error getting recent data from ${tableName}: ${error.message}`);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({
                table: tableName,
                recentData: data
              }, null, 2)
            }
          ]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error.message}`
        }
      ],
      isError: true
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("TakEsep Supabase MCP server running on stdio");
}

main().catch(console.error);
