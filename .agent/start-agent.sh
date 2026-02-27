#!/bin/bash

# AI Agent Launcher (Autonomous Mode)
# Starts an AI coding agent for this project
# Supports: Claude Code, OpenCode, Codex CLI
# Agents work through the backlog autonomously until work is complete
# Run from your project directory: ./.agent/start-agent.sh

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Default OpenCode web port
OPENCODE_PORT="${OPENCODE_PORT:-4096}"
OPENCODE_HOST="${OPENCODE_HOST:-127.0.0.1}"

# Get the directory where we're running from (the project)
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect available agent (prefer Claude Code > OpenCode > Codex)
AGENT=""
if [ -n "$AGENT_CLI" ]; then
    AGENT="$AGENT_CLI"
elif command -v claude &> /dev/null; then
    AGENT="claude"
elif command -v opencode &> /dev/null; then
    AGENT="opencode"
elif command -v codex &> /dev/null; then
    AGENT="codex"
fi

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             AI Agent Launcher (Autonomous)                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "Project: ${CYAN}$PROJECT_NAME${NC}"
echo -e "Path:    ${CYAN}$PROJECT_DIR${NC}"
echo -e "Agent:   ${CYAN}${AGENT:-none found}${NC}"
echo ""

if [ -z "$AGENT" ]; then
    echo -e "${RED}Error: No agent CLI found. Install one of:${NC}"
    echo -e "  npm i -g @anthropic-ai/claude-code   ${CYAN}# Claude Code${NC}"
    echo -e "  npm i -g opencode                     ${CYAN}# OpenCode${NC}"
    echo -e "  npm i -g @openai/codex                ${CYAN}# Codex CLI${NC}"
    echo ""
    echo -e "Or set AGENT_CLI=claude|opencode|codex"
    exit 1
fi

# Determine the appropriate prompt based on state
HANDOFF_FILE="$SCRIPT_DIR/handoff/HANDOFF.md"
BACKLOG_FILE="$SCRIPT_DIR/backlog/BACKLOG.md"

if [ -f "$HANDOFF_FILE" ]; then
    # Priority 1: Continue from handoff
    echo -e "${YELLOW}Found pending handoff at .agent/handoff/HANDOFF.md${NC}"
    INITIAL_PROMPT="Continue autonomous work from handoff.

Before starting:
1. Read .agent/handoff/HANDOFF.md — understand current state
2. Read .agent/AGENTS.md — understand operating protocol
3. Read .agent/CURRENT_WORK.md — restore session memory
4. Read .agent/MEMORY.md — long-term project knowledge
5. Read .agent/LESSONS.md — avoid past mistakes
6. Check .agent/backlog/BACKLOG.md — see the full work queue
7. Continue from 'Continue From Here' in handoff

As you work:
- Use TodoWrite for in-session task tracking (survives context compaction)
- Update .agent/CURRENT_WORK.md every 2-3 completed tasks
- When you learn something durable (a fact, gotcha, convention, or decision), write it to the appropriate memory file (MEMORY.md, PATTERNS.md, DECISIONS.md, or LESSONS.md)
- Commit frequently with conventional commit messages

Work autonomously until backlog is empty or you need to hand off."

elif [ -f "$BACKLOG_FILE" ]; then
    # Priority 2: Work from backlog
    echo -e "${GREEN}No pending handoff. Checking backlog...${NC}"
    
    # Check if there's a current item or ready items
    if grep -q "current:" "$BACKLOG_FILE" 2>/dev/null; then
        echo -e "${CYAN}Backlog found. Agent will work autonomously.${NC}"
    fi
    
    INITIAL_PROMPT="Read .agent/AGENTS.md and follow ALL instructions there.

Before starting any work:
1. Read .agent/CURRENT_WORK.md to understand what was happening last session
2. Read .agent/MEMORY.md for long-term project knowledge
3. Read .agent/LESSONS.md so you don't repeat past mistakes
4. Check .agent/backlog/BACKLOG.md for prioritised work items
5. Pick the highest priority 'ready' item

As you work:
- Use TodoWrite to track your tasks (survives context compaction)
- Update .agent/CURRENT_WORK.md every 2-3 completed tasks
- When you learn something durable (a fact, gotcha, convention, or decision), write it to the appropriate memory file (MEMORY.md, PATTERNS.md, DECISIONS.md, or LESSONS.md)
- Commit frequently with conventional commit messages

Work autonomously — do not wait for human input between work items.
Continue until backlog is empty or token limit."

else
    # No backlog - fall back to task-based mode
    echo -e "${YELLOW}No backlog found. Starting in task mode.${NC}"
    echo ""
    echo -e "${YELLOW}What would you like the agent to work on?${NC}"
    echo "(Press Enter to just open the project)"
    read -p "Task: " TASK
    
    if [ -n "$TASK" ]; then
        INITIAL_PROMPT="Read .agent/AGENTS.md and follow ALL instructions there.

Before starting any work:
1. Read .agent/CURRENT_WORK.md to understand what was happening last session
2. Read .agent/MEMORY.md for long-term project knowledge
3. Read .agent/LESSONS.md so you don't repeat past mistakes

As you work:
- Use TodoWrite to track your tasks (survives context compaction)
- Update .agent/CURRENT_WORK.md every 2-3 completed tasks
- When you learn something durable (a fact, gotcha, convention, or decision), write it to the appropriate memory file (MEMORY.md, PATTERNS.md, DECISIONS.md, or LESSONS.md)
- Commit frequently with conventional commit messages

Task: $TASK"
    else
        INITIAL_PROMPT="Read .agent/AGENTS.md and follow ALL instructions there.

Before starting:
1. Read .agent/CURRENT_WORK.md for previous session state
2. Read .agent/MEMORY.md for project knowledge
3. Read .agent/LESSONS.md for known gotchas

Check .agent/backlog/BACKLOG.md for work items. If backlog exists, work autonomously. If not, wait for instructions.
Update memory files as you work."
    fi
fi

echo ""

# Function to show prompt and copy to clipboard
show_prompt() {
    echo ""
    echo -e "${YELLOW}Paste this prompt in the chat:${NC}"
    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo "$INITIAL_PROMPT"
    echo "─────────────────────────────────────────────────────────────"
    
    # Copy to clipboard
    if command -v pbcopy &> /dev/null; then
        echo "$INITIAL_PROMPT" | pbcopy
        echo ""
        echo -e "${GREEN}Prompt copied to clipboard!${NC}"
    fi
}

# Launch based on agent type
case "$AGENT" in
    claude)
        echo -e "${CYAN}Launching Claude Code...${NC}"
        show_prompt
        echo ""
        echo -e "${BLUE}Starting Claude Code in ${PROJECT_DIR}...${NC}"
        cd "$PROJECT_DIR"
        exec claude
        ;;
    
    codex)
        echo -e "${CYAN}Launching Codex CLI...${NC}"
        show_prompt
        echo ""
        echo -e "${BLUE}Starting Codex in ${PROJECT_DIR}...${NC}"
        cd "$PROJECT_DIR"
        exec codex
        ;;
    
    opencode)
        # Encode project path for URL
        ENCODED_PATH=$(echo -n "$PROJECT_DIR" | base64 | tr -d '\n')
        PROJECT_URL="http://${OPENCODE_HOST}:${OPENCODE_PORT}/${ENCODED_PATH}"
        
        # Check if OpenCode web is already running
        if curl -s --connect-timeout 2 "http://${OPENCODE_HOST}:${OPENCODE_PORT}" > /dev/null 2>&1; then
            echo -e "${GREEN}OpenCode web is already running on port ${OPENCODE_PORT}${NC}"
            echo -e "${CYAN}Opening project in Brave browser...${NC}"
            # Open in default browser (override with BROWSER env var)
            if [ -n "$BROWSER" ]; then
                "$BROWSER" "$PROJECT_URL"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "$PROJECT_URL"
            elif command -v open &> /dev/null; then
                open "$PROJECT_URL"
            else
                echo -e "${YELLOW}Open manually: $PROJECT_URL${NC}"
            fi
            show_prompt
        else
            echo -e "${YELLOW}OpenCode web not running. Starting it now...${NC}"
            echo ""
            
            if command -v pbcopy &> /dev/null; then
                echo "$INITIAL_PROMPT" | pbcopy
                echo -e "${GREEN}Prompt copied to clipboard!${NC}"
            fi
            
            show_prompt
            echo ""
            echo -e "${BLUE}Starting OpenCode web...${NC}"
            cd "$PROJECT_DIR"
            exec opencode web --port "$OPENCODE_PORT"
        fi
        ;;
    
    *)
        echo -e "${RED}Unknown agent: $AGENT${NC}"
        exit 1
        ;;
esac
