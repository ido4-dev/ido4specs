#!/bin/bash
# Generate skill inventory tables for README.md
# Reads SKILL.md frontmatter from all skills and produces two markdown tables:
# - Commands (user-invocable skills with /ido4specs: prefix)
# - Supporting skills (auto-triggered)
# Adapted from ido4shape's generate-skill-inventory.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

PLUGIN_DIR="$PLUGIN_DIR" python3 << 'PYSCRIPT'
import os, re, glob

plugin_dir = os.environ.get("PLUGIN_DIR", ".")
skills_dir = os.path.join(plugin_dir, "skills")
readme_path = os.path.join(plugin_dir, "README.md")

commands = []
supporting = []

for skill_file in sorted(glob.glob(os.path.join(skills_dir, "*/SKILL.md"))):
    content = open(skill_file).read()
    name = os.path.basename(os.path.dirname(skill_file))

    # Extract user-invocable
    m = re.search(r'^user-invocable:\s*(true|false)', content, re.MULTILINE)
    is_auto = m and m.group(1) == "false"

    # Extract first sentence of description
    m = re.search(r'^description:\s*>?\s*\n?\s*(.+?)(?:\n[a-zA-Z]|\n---)', content, re.MULTILINE | re.DOTALL)
    if m:
        desc = re.sub(r'\s+', ' ', m.group(1).strip())
        desc = re.split(r'(?<=[.!?])\s', desc)[0]
        desc = re.sub(r'^This skill\s+', '', desc)
        desc = desc[0].upper() + desc[1:] if desc else desc
        if len(desc) > 120:
            desc = desc[:117] + "..."
    else:
        desc = ""

    if is_auto:
        supporting.append(f"| `{name}` | {desc} |")
    else:
        commands.append(f"| `/ido4specs:{name}` | {desc} |")

commands_table = "| Skill | Description |\n|-------|-------------|\n" + "\n".join(commands)

section = f"""<!-- BEGIN SKILL INVENTORY -->
## Skills

### Commands

{commands_table}"""

if supporting:
    supporting_table = "| Skill | Description |\n|-------|-------------|\n" + "\n".join(supporting)
    section += f"""

### Auto-triggered skills

These activate automatically during conversation when relevant — you don't invoke them directly.

{supporting_table}"""

section += "\n<!-- END SKILL INVENTORY -->"

# Update README
if os.path.exists(readme_path):
    readme = open(readme_path).read()
    if "BEGIN SKILL INVENTORY" in readme:
        result = re.sub(
            r'<!-- BEGIN SKILL INVENTORY -->.*?<!-- END SKILL INVENTORY -->',
            section, readme, flags=re.DOTALL
        )
        open(readme_path, 'w').write(result)
        print("README.md skill inventory updated")
    else:
        print("No markers found in README.md")
        print(section)
else:
    print(section)
PYSCRIPT
