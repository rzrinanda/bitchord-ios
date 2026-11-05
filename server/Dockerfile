FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production || true

COPY . .

EXPOSE 3000

ENV PORT=3000
ENV HOST=0.0.0.0

CMD ["node", "index.js"]
