FROM node:24-alpine
WORKDIR /app
COPY pnpm-workspace.yaml pnpm-lock.yaml ./
COPY web/react-console/package.json ./web/react-console/package.json
RUN corepack enable && pnpm install --filter institutional-yield-react-console --frozen-lockfile
COPY web/react-console ./web/react-console
RUN CI=true pnpm --filter institutional-yield-react-console build
EXPOSE 5173
CMD ["pnpm", "--filter", "institutional-yield-react-console", "dev"]
