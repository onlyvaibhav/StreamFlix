/**
 * Utility for parsing and identifying client IP addresses behind proxies, Cloudflare, local networks, and direct connections.
 */

function isPrivateIp(ip) {
  if (!ip || typeof ip !== 'string') return true;
  const cleanIp = ip.replace(/^::ffff:/, '').trim();

  if (cleanIp === '127.0.0.1' || cleanIp === '::1' || cleanIp === 'localhost') return true;

  // 10.0.0.0 – 10.255.255.255
  if (/^10\./.test(cleanIp)) return true;

  // 172.16.0.0 – 172.31.255.255
  if (/^172\.(1[6-9]|2[0-9]|3[01])\./.test(cleanIp)) return true;

  // 192.168.0.0 – 192.168.255.255
  if (/^192\.168\./.test(cleanIp)) return true;

  // Carrier-grade NAT (100.64.0.0 – 100.127.255.255)
  if (/^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\./.test(cleanIp)) return true;

  // Link-local (169.254.0.0 – 169.254.255.255)
  if (/^169\.254\./.test(cleanIp)) return true;

  return false;
}

function getClientIp(req) {
  if (!req) return 'Unknown';

  // 1. Cloudflare header
  const cfIp = req.headers?.['cf-connecting-ip'];
  if (cfIp && typeof cfIp === 'string' && cfIp.trim()) {
    return cfIp.trim();
  }

  // 2. X-Real-IP (NGINX / Caddy / Reverse Proxy)
  const realIp = req.headers?.['x-real-ip'];
  if (realIp && typeof realIp === 'string' && realIp.trim()) {
    return realIp.trim();
  }

  // 3. X-Forwarded-For (Standard proxy header: client, proxy1, proxy2)
  const forwarded = req.headers?.['x-forwarded-for'];
  if (forwarded && typeof forwarded === 'string' && forwarded.trim()) {
    const ips = forwarded.split(',').map(s => s.trim()).filter(Boolean);
    if (ips.length > 0) return ips[0];
  }

  // 4. Express req.ip or connection remoteAddress
  let rawIp = req.ip || req.connection?.remoteAddress || req.socket?.remoteAddress || 'Unknown';

  if (typeof rawIp === 'string' && rawIp.startsWith('::ffff:')) {
    rawIp = rawIp.substring(7);
  }

  return rawIp;
}

function formatIpForDisplay(ip) {
  if (!ip || ip === 'Unknown') return 'Unknown';
  if (isPrivateIp(ip)) {
    if (ip === '127.0.0.1' || ip === '::1' || ip === 'localhost') return `${ip} (Localhost)`;
    return `${ip} (Local Wi-Fi / Private LAN)`;
  }
  return ip;
}

module.exports = {
  getClientIp,
  isPrivateIp,
  formatIpForDisplay
};
