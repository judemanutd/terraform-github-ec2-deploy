# Common build stage
FROM node:18.12-alpine3.17 as common-build-stage

COPY . ./app

WORKDIR /app

RUN npm install

# Development build stage
FROM common-build-stage as development-build-stage

ENV NODE_ENV development

CMD ["npm", "run", "dev"]

# Production build stage
FROM common-build-stage as production-build-stage

ENV NODE_ENV production

CMD ["npm", "run", "start"]
