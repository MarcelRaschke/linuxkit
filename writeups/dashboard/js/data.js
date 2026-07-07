const CTF_META = {
  name: "EotW CTF SS CASE IT 2025",
  team: "AI Cy8er Command Center",
  year: 2025
};

const CATEGORIES = [
  { id: "forensics",    name: "Forensics",              icon: "\u{1F50D}" },
  { id: "web",          name: "Web Exploitation",       icon: "\u{1F310}" },
  { id: "crypto",       name: "Cryptography",           icon: "\u{1F512}" },
  { id: "reversing",    name: "Reverse Engineering",    icon: "⚙️" },
  { id: "pwn",          name: "Binary Exploitation",    icon: "\u{1F4A5}" },
  { id: "misc",         name: "Miscellaneous",          icon: "\u{1F9E9}" },
  { id: "osint",        name: "OSINT",                  icon: "\u{1F30D}" },
  { id: "stego",        name: "Steganography",          icon: "\u{1F5BC}️" }
];

const CHALLENGES = [
  {
    id: "ai-command-center",
    category: "forensics",
    title: "AI Cy8er Command Center",
    points: 500,
    difficulty: "Hard",
    solved: true,
    // Path is relative to the dashboard root (writeups/dashboard/); the
    // renderer prepends the page-depth prefix so it resolves from any page.
    writeup: "../forensics/ai-command-center.md",
    summary: "Forensic analysis of an AI command and control infrastructure."
  }
];

function getStats() {
  const total = CHALLENGES.length;
  const solved = CHALLENGES.filter(c => c.solved).length;
  const points = CHALLENGES.filter(c => c.solved).reduce((s, c) => s + c.points, 0);
  const byCategory = {};
  CATEGORIES.forEach(cat => {
    const challs = CHALLENGES.filter(c => c.category === cat.id);
    byCategory[cat.id] = {
      total: challs.length,
      solved: challs.filter(c => c.solved).length,
      points: challs.filter(c => c.solved).reduce((s, c) => s + c.points, 0)
    };
  });
  return { total, solved, points, byCategory };
}

function getChallengesByCategory(catId) {
  return CHALLENGES.filter(c => c.category === catId);
}
