const puppeteer = require("puppeteer");
const fs = require("fs");

async function main() {
  const [htmlPath, outputPath] = process.argv.slice(2);

  if (!htmlPath || !outputPath) {
    console.error("Usage: node html2pdf.mjs <html-file> <output-pdf>");
    process.exit(1);
  }

  const html = fs.readFileSync(htmlPath, "utf-8");

  const browser = await puppeteer.launch({ headless: true, args: ["--no-sandbox"] });
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "networkidle0" });
  await page.pdf({
    path: outputPath,
    format: "A4",
    margin: { top: "0.5in", right: "0.5in", bottom: "0.5in", left: "0.5in" },
    printBackground: true,
  });
  await browser.close();
  console.log("PDF written to " + outputPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
