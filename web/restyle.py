import re

css_path = 'src/App.css'

with open(css_path, 'r') as f:
    css = f.read()

# 1. Replace variables
css = re.sub(r':root\s*\{[^}]+\}', ''':root {
  --bg-deep: linear-gradient(135deg, #E6E9FF 0%, #F4F0FF 100%);
  --bg-col: #ffffff;
  --bg-panel: #ffffff;
  --bg-card: rgba(0, 0, 0, 0.02);
  --bg-card-hover: rgba(0, 0, 0, 0.05);

  --ink: #1E293B;
  --muted: #64748B;
  --dim: #94A3B8;

  --cyan: #00CBD2;
  --cyan-glow: rgba(0, 203, 210, 0.2);
  --purple: #8B5CF6;
  --purple-glow: rgba(139, 92, 246, 0.15);
  --red: #FF4757;

  --glass-border: rgba(0, 0, 0, 0.05);
  --glass-hi: rgba(255, 255, 255, 1);
  --radius: 24px;
  --radius-sm: 16px;
  --shadow-card: 0 10px 30px rgba(0, 0, 0, 0.05);

  --font-display: 'Space Grotesk', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', monospace;
}''', css)

# 2. Modify app-shell to grid gap and padding
css = re.sub(r'(\.app-shell\s*\{[^}]+)(height:\s*100vh;)', r'\1\2\n  padding: 16px;\n  gap: 16px;\n  box-sizing: border-box;', css)

# 3. Modify internal columns (remove border, add box-shadow, height)
css = re.sub(r'(\.col\s*\{[^}]+)(height:\s*100vh;)', r'\1height: 100%;\n  background: var(--bg-col);\n  border-radius: var(--radius);\n  box-shadow: var(--shadow-card);\n  border: 1px solid var(--glass-border);', css)

# remove background and border from .col-left, .col-center, .col-right
css = re.sub(r'\.col-left\s*\{[^}]+\}', '.col-left { padding: 20px; }', css)
css = re.sub(r'\.col-center\s*\{[^}]+\}', '.col-center { padding: 32px 40px; }', css)
css = re.sub(r'\.col-right\s*\{[^}]+\}', '.col-right { padding: 20px; }', css)

# 4. Modify typography center title linearly gradient
css = re.sub(r'h1\.center-title\s*\{[^}]+\}', '''h1.center-title {
  font-family: var(--font-display);
  font-size: 2.6rem;
  font-weight: 700;
  letter-spacing: -0.04em;
  margin: 0 0 4px 0;
  color: var(--ink);
}''', css)

# 5. Modify left tabs to match Figma (pill design)
css = re.sub(r'\.left-tabs\s*\{[^}]+\}', '''.left-tabs {
  display: flex;
  gap: 4px;
  margin-bottom: 20px;
  background: var(--bg-card);
  border-radius: 99px;
  padding: 4px;
}''', css)
css = re.sub(r'\.left-tab\.active\s*\{[^}]+\}', '''.left-tab.active {
  background: #ffffff;
  color: var(--cyan);
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}''', css)

# 6. Mode toggle matching Figma
css = re.sub(r'\.mode-toggle\s*\{[^}]+\}', '''.mode-toggle {
  display: flex;
  background: var(--bg-card);
  border-radius: 99px;
  padding: 4px;
  height: max-content;
}''', css)

css = re.sub(r'\.mode-btn\.active\s*\{[^}]+\}', '''.mode-btn.active {
  background: var(--cyan);
  color: white;
  box-shadow: 0 2px 8px var(--cyan-glow);
}''', css)

# 7. Modify input areas
css = re.sub(r'\.topic-input\s*\{[^}]+\}', '''.topic-input {
  width: 100%;
  height: 90px;
  background: var(--bg-card);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-sm);
  padding: 16px;
  color: var(--ink);
  font-family: inherit;
  font-size: 0.95rem;
  resize: none;
  outline: none;
  transition: all 0.2s;
}
.topic-input:focus {
  background: #ffffff;
  border-color: var(--cyan);
  box-shadow: 0 0 0 3px var(--cyan-glow);
}''', css)

# Remove glowing blobs pseudo elements
css = re.sub(r'\.app-shell::before,\s*\.app-shell::after\s*\{[^}]+\}', '', css)
css = re.sub(r'\.app-shell::before\s*\{[^}]+\}', '', css)
css = re.sub(r'\.app-shell::after\s*\{[^}]+\}', '', css)

with open(css_path, 'w') as f:
    f.write(css)

print("CSS transformed")
