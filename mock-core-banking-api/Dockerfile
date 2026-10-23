FROM node:22-alpine
WORKDIR /app
COPY server.mjs ./
COPY data ./data
ENV PORT=8080
EXPOSE 8080
USER node
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "server.mjs"]
