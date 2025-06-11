# Edge Functions runtime for Cloud Run
FROM denoland/deno:alpine-1.38.0

# Install dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

# Create app directory
WORKDIR /app

# Copy function files (this would be populated during deployment)
COPY ./functions /app/functions

# Create a simple router
RUN echo 'import { serve } from "https://deno.land/std@0.168.0/http/server.ts";\n\
const handler = async (request: Request): Promise<Response> => {\n\
  const url = new URL(request.url);\n\
  const functionName = url.pathname.split("/")[2];\n\
  \n\
  try {\n\
    const module = await import(`./functions/${functionName}/index.ts`);\n\
    return await module.default(request);\n\
  } catch (error) {\n\
    return new Response(JSON.stringify({ error: "Function not found" }), {\n\
      status: 404,\n\
      headers: { "Content-Type": "application/json" },\n\
    });\n\
  }\n\
};\n\
\n\
serve(handler, { port: 8000 });' > /app/server.ts

# Run the server
EXPOSE 8000
CMD ["run", "--allow-all", "/app/server.ts"]