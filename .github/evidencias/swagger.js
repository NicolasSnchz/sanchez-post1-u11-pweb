// Capturas de Swagger UI (http://localhost:8080/swagger-ui.html) en Chromium.
// uso: node swagger.js <carpeta-capturas>
const { chromium } = require('playwright');
const [salida] = process.argv.slice(2);
(async () => {
  const navegador = await chromium.launch();
  const p = await navegador.newPage({ viewport: { width: 1366, height: 900 } });
  await p.goto('http://localhost:8080/swagger-ui.html');
  await p.waitForSelector('.opblock', { timeout: 30000 });
  await p.waitForTimeout(1000);
  console.log('operaciones:', await p.locator('.opblock').count(), 'url:', p.url());
  await p.screenshot({ path: `${salida}/swagger-ui.png`, fullPage: true });
  console.log('captura swagger-ui.png');

  // Cada operacion expandida: descripcion, parametros, cuerpo de ejemplo y respuestas posibles
  for (const [id, nombre] of [['crear', 'swagger-post.png'], ['obtener', 'swagger-get.png']]) {
    const bloque = p.locator(`#operations-Pedidos-${id}`);
    await bloque.locator('.opblock-summary').first().click();
    await bloque.locator('.responses-wrapper').waitFor({ timeout: 15000 });
    await p.waitForTimeout(800);
    await bloque.screenshot({ path: `${salida}/${nombre}` });
    console.log('captura', nombre);
    await bloque.locator('.opblock-summary').first().click();
    await p.waitForTimeout(500);
  }
  await navegador.close();
})().catch(e => { console.error('FALLO swagger:', e.message); process.exit(1); });
