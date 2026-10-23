"""Generate the updated project proposal PDF for 'The Colony Was Automated'."""
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable

OUT = Path(__file__).resolve().parent.parent / "The_Colony_Was_Automated_Proposal.pdf"

TITLE = ParagraphStyle("Title", fontName="Helvetica-Bold", fontSize=20, leading=25,
                       textColor=colors.HexColor("#1e3d2f"), spaceAfter=2)
SUBTITLE = ParagraphStyle("Subtitle", fontName="Helvetica-Oblique", fontSize=12, leading=15,
                          textColor=colors.HexColor("#4a6b57"), spaceAfter=10)
H = ParagraphStyle("H", fontName="Helvetica-Bold", fontSize=13, leading=16,
                   textColor=colors.HexColor("#1e3d2f"), spaceBefore=12, spaceAfter=4)
BODY = ParagraphStyle("Body", fontName="Helvetica", fontSize=10.5, leading=15,
                      alignment=4, spaceAfter=5)  # justified
BULLET = ParagraphStyle("Bullet", parent=BODY, leftIndent=14, bulletIndent=4, spaceAfter=3)
NUM = ParagraphStyle("Num", parent=BODY, leftIndent=16, bulletIndent=2, spaceAfter=2)
CODE = ParagraphStyle("Code", fontName="Courier", fontSize=9.5, leading=13, leftIndent=18,
                      textColor=colors.HexColor("#333333"), backColor=colors.HexColor("#f2f2ec"),
                      borderPadding=5, spaceBefore=3, spaceAfter=6)


def b(text):
    return Paragraph(text, BULLET, bulletText="\u2022")


def n(i, text):
    return Paragraph(text, NUM, bulletText=f"{i}.")


story = []
story.append(Paragraph("Object-Oriented Programming Project Proposal", SUBTITLE))
story.append(Paragraph("The Colony Was Automated", TITLE))
story.append(Paragraph("Alias: <b>Colony Engine</b> &nbsp;|&nbsp; Built with Godot 4 (GDScript) for desktop, with a web export", SUBTITLE))
story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#1e3d2f"), spaceAfter=6))

# --- 1. Project Title -------------------------------------------------------
story.append(Paragraph("1. Project Title", H))
story.append(Paragraph("<b>Title:</b> The Colony Was Automated", BODY))
story.append(Paragraph("<b>Alias:</b> Colony Engine", BODY))

# --- 2. Project Description -------------------------------------------------
story.append(Paragraph("2. Project Description", H))
story.append(Paragraph(
    "The Colony Was Automated is a colony simulation and management game where players create and manage a "
    "virtual colony of ants on a procedurally generated island. Instead of directly controlling each creature, "
    "players write behavior rules in a small, beginner-friendly rule language inside the game. The rules determine "
    "how colony members gather food and materials, build structures, explore the map, defend the nest, flee from "
    "danger, and recover from injuries. The primary purpose is to demonstrate how programmed behaviors can create "
    "an organized and efficient colony.", BODY))
story.append(Paragraph(
    "The game is won by keeping the colony alive: every 20 minutes the queen demands a payment of food that grows "
    "with each cycle, and failing to meet her demand ends the colony. Players expand by constructing buildings such "
    "as hatcheries, storages, guard posts, tunnels, farms, and workshops.", BODY))
story.append(Paragraph(
    "<b>Intended Users:</b> Students, simulation enthusiasts, and users interested in programming, automation, and "
    "strategy games.", BODY))

# --- 3. Needs ---------------------------------------------------------------
story.append(Paragraph("3. Needs (Problem Statement)", H))
story.append(Paragraph(
    "Managing many individual creatures manually can be inefficient and difficult, especially when each creature has "
    "different tasks and needs. Students and beginner programmers may also have difficulty understanding how "
    "object-oriented programming and automated decision-making can be applied to a practical system. This project "
    "addresses these problems by allowing users to manage a colony through rules and automated behaviors instead of "
    "controlling every creature individually.", BODY))

# --- 4. Solution ------------------------------------------------------------
story.append(Paragraph("4. Solution", H))
story.append(Paragraph(
    "The application provides a virtual colony where users create ants, assign roles, and write behavior rules for "
    "different situations. The solution demonstrates OOP concepts such as classes, objects, inheritance, "
    "encapsulation, and polymorphism through an interactive simulation: every ant is an object with its own state "
    "(health, cargo, role), the rule language is encapsulated in a dedicated interpreter class, and each role "
    "executes its own script through the same decision-making interface.", BODY))
story.append(Paragraph("Implemented features include:", BODY))
story.append(b("<b>Creature management</b> \u2013 spawn ants and assign four roles: Worker, Explorer, Defender, and Guard."))
story.append(b("<b>Custom rule language</b> \u2013 26 conditions and 13 actions, with and/or/not logic, parentheses, "
               "reusable named conditions (<i>define</i>), comments, and friendly word aliases."))
story.append(b("<b>Per-role rule scripts</b> \u2013 each role runs its own script, so workers, explorers, defenders, and "
               "guards can behave differently."))
story.append(b("<b>In-game rule editor</b> \u2013 type rules directly or build them from dropdown menus, with "
               "auto-completion, syntax validation that pinpoints the exact line and column of errors, a dry-run "
               "preview against sample situations, and a built-in 14-lesson tutorial."))
story.append(b("<b>Resource gathering</b> \u2013 two resources, food and materials, with limited storage that must be expanded."))
story.append(b("<b>Colony building</b> \u2013 place blueprints for seven structures (hatchery, food storage, material storage, "
               "guard post, tunnel, farm, workshop); workers construct them over time."))
story.append(b("<b>Combat and survival</b> \u2013 roaming bugs attack the colony; ants can fight, flee, rest, and heal."))
story.append(b("<b>Queen demand cycle</b> \u2013 a periodic food quota acts as the win/lose pressure on the colony."))
story.append(b("<b>Procedurally generated world</b> \u2013 islands with water, land, and hills, explored with a movable camera."))
story.append(b("<b>Save/load system</b> \u2013 three save slots store the colony and all rule scripts, from the menu or in-game."))
story.append(b("<b>Difficulty levels</b> \u2013 Easy, Normal, and Hard change bug pressure and starting resources."))

# --- 5. Differentiation -----------------------------------------------------
story.append(Paragraph("5. Differentiation (Unique Value)", H))
story.append(Paragraph(
    "Unlike traditional colony management games where users directly issue commands to individual units, Colony "
    "Engine focuses on programming behaviors and rules that allow creatures to make decisions independently. For "
    "example, a player can write rules so that an ant flees when badly hurt, returns home when its carrying capacity "
    "is reached, gathers food when food is nearby, and otherwise stays productive:", BODY))
story.append(Paragraph(
    "critical_health: flee<br/>food_full: return<br/>worker and food_near: collect_food<br/>always: idle", CODE))
story.append(Paragraph(
    "Rules are read top to bottom and the first matching rule wins, so ordering becomes a puzzle in itself. Players "
    "can test a draft against sample situations before applying it, then watch the whole colony change behavior at "
    "once. This makes the project both a simulation and a practical demonstration of automated decision-making.", BODY))

# --- 6. Benefits ------------------------------------------------------------
story.append(Paragraph("6. Benefits", H))
story.append(Paragraph(
    "Users learn how automation and object-oriented programming can be applied to a dynamic system while "
    "experimenting with different strategies for managing a colony. The automated behavior system reduces the need "
    "for constant manual control and allows users to observe how individual decisions produce larger colony-level "
    "behavior. The in-game tutorial, dropdown rule builder, and draft preview lower the barrier for beginners, while "
    "the rule-ordering and logic operators reward problem-solving and logical-thinking skills as users create more "
    "efficient behavior rules.", BODY))

# --- 7. SDGs ----------------------------------------------------------------
story.append(Paragraph("7. Sustainable Development Goals (SDGs)", H))
story.append(b("<b>SDG 4</b> \u2013 Quality Education"))
story.append(b("<b>SDG 9</b> \u2013 Industry, Innovation and Infrastructure"))
story.append(b("<b>SDG 15</b> \u2013 Life on Land"))
story.append(Paragraph(
    "<b>Alignment:</b> The project supports SDG 4 by providing an interactive way to learn programming, logic, and "
    "automation, including a step-by-step in-game course on writing behavior rules. It supports SDG 9 by "
    "demonstrating technological innovation and automated systems, while SDG 15 is represented through the simulation "
    "of creatures interacting with their environment.", BODY))

# --- 8. User Journey --------------------------------------------------------
story.append(Paragraph("8. User Journey", H))
journey = [
    "Open the application and read the title screen.",
    "Choose a difficulty (Easy, Normal, or Hard).",
    "Start a new colony or load an existing one from a save slot.",
    "View the colony dashboard: food, materials, population, and the queen's demand timer.",
    "Add ants and assign roles such as Worker, Explorer, Defender, or Guard.",
    "Open the rule editor from the Commands panel.",
    "Pick a role's script and create behavior rules by typing or using the dropdown builder.",
    "Test the draft rules against sample situations, then apply them.",
    "Place building blueprints; workers construct them automatically.",
    "Observe ants gathering, building, exploring, fighting, fleeing, and healing according to their programmed rules.",
    "Meet the queen's food demand before her timer runs out.",
    "Modify behavior rules when the colony becomes inefficient or encounters new problems, then watch the changes.",
    "Save the colony and its rule scripts into one of the three save slots.",
    "Return to the menu or exit the application.",
]
for i, step in enumerate(journey, 1):
    story.append(n(i, step))

doc = SimpleDocTemplate(str(OUT), pagesize=A4,
                        leftMargin=20 * mm, rightMargin=20 * mm,
                        topMargin=18 * mm, bottomMargin=18 * mm,
                        title="The Colony Was Automated - Project Proposal",
                        author="Colony Engine")
doc.build(story)
print(f"PDF written to: {OUT}")
