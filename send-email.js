#!/usr/bin/env node
/**
 * Send Garmin Recap Email via Resend
 * Reads the generated markdown recap and emails it.
 */

const fs = require('fs');
const path = require('path');

// Check for Resend package
let Resend;
try {
  ({ Resend } = require('resend'));
} catch (err) {
  console.error('Resend package not found. Installing...');
  const { execSync } = require('child_process');
  execSync('npm install resend', { stdio: 'inherit', cwd: __dirname });
  ({ Resend } = require('resend'));
}

// Load environment variables from .env.local in the website project
const envPath = path.join(process.env.HOME, 'Desktop', 'joseandgoose-site-main', '.env.local');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const [key, ...valueParts] = line.split('=');
    if (key && valueParts.length > 0) {
      const value = valueParts.join('=').trim();
      if (key.includes('RESEND_API_KEY') || key.includes('NOTIFICATION_EMAIL')) {
        process.env[key.trim()] = value;
      }
    }
  });
}

const RESEND_API_KEY = process.env.RESEND_API_KEY;
const NOTIFICATION_EMAIL = process.env.NOTIFICATION_EMAIL || 'odagledesoj@gmail.com';

if (!RESEND_API_KEY) {
  console.error('ERROR: RESEND_API_KEY not found in environment');
  process.exit(1);
}

// Get recap file path from command line argument
const recapFile = process.argv[2];
if (!recapFile || !fs.existsSync(recapFile)) {
  console.error('ERROR: Recap file not found:', recapFile);
  process.exit(1);
}

// Read the markdown recap
const recapContent = fs.readFileSync(recapFile, 'utf-8');

// Convert markdown to HTML (simple conversion - preserves structure)
const htmlContent = recapContent
  .replace(/^# (.*?)$/gm, '<h1>$1</h1>')
  .replace(/^## (.*?)$/gm, '<h2>$1</h2>')
  .replace(/^### (.*?)$/gm, '<h3>$3</h3>')
  .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
  .replace(/^- (.*?)$/gm, '<li>$1</li>')
  .replace(/\n\n/g, '</p><p>')
  .replace(/^(?!<[h|l|p])(.*?)$/gm, '<p>$1</p>')
  .replace(/<\/p><p><li>/g, '<ul><li>')
  .replace(/<\/li><\/p>/g, '</li></ul>');

// Get date from filename (garmin-recap-2026-02-28.md)
const dateMatch = recapFile.match(/(\d{4}-\d{2}-\d{2})/);
const date = dateMatch ? dateMatch[1] : new Date().toISOString().split('T')[0];

// Send email via Resend
const resend = new Resend(RESEND_API_KEY);

(async () => {
  try {
    const { data, error } = await resend.emails.send({
      from: 'Garmin Daily Recap <onboarding@resend.dev>',
      to: NOTIFICATION_EMAIL,
      subject: `🏃 Your Garmin Health Recap — ${date}`,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #1c1c1c;">
          ${htmlContent}
        </div>
      `,
    });

    if (error) {
      console.error('Resend API error:', error);
      process.exit(1);
    }

    console.log(`✅ Email sent to ${NOTIFICATION_EMAIL}`);
    console.log(`   Message ID: ${data?.id}`);
  } catch (err) {
    console.error('Failed to send email:', err);
    process.exit(1);
  }
})();
