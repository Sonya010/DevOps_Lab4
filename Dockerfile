FROM node:20-alpine

WORKDIR /opt/mywebapp

COPY package*.json ./
RUN npm install

COPY . .

ENV NODE_ENV=development

EXPOSE 8000

CMD node migrate.js && node app.js