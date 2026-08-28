const fs = require('fs');
const path = '/app/src/app.ts';
let s = fs.readFileSync(path, 'utf8');
if (s.includes('/uploads')) {
  console.log('static uploads already configured');
  process.exit(0);
}
s = s.replace(
  'import express from "express";',
  `import express from "express";\nimport path from "path";`
);
s = s.replace(
  'app.use(pinoHttp({ logger }));',
  `app.use(pinoHttp({ logger }));
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));`
);
fs.writeFileSync(path, s);
console.log('static uploads route added');
