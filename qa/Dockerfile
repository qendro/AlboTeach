FROM mcr.microsoft.com/playwright:v1.56.1-noble
WORKDIR /qa
RUN npm init -y >/dev/null && npm install --save-exact playwright@1.56.1
COPY smoke.cjs ./smoke.cjs
COPY connection.cjs ./connection.cjs
COPY printing.cjs ./printing.cjs
ENTRYPOINT ["node", "/qa/smoke.cjs"]
