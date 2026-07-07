# SwiftMarkdownReader - User Guide & Testing Manual

**Version**: 1.1  
**Platform**: macOS 14+  
**Last Updated**: May 2026

---

## Getting Started

### System Requirements
- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

### Building & Running

```bash
# Build
swift build --product MarkdownReader-macOS

# Run
open .build/arm64-apple-macosx/debug/MarkdownReader-macOS
```

### First Launch
The app opens with a three-column layout:
1. **Left sidebar** — Navigation (Outline, Search, Source, Files, Themes, Settings)
2. **Middle pane** — Content for the selected sidebar item
3. **Right pane** — Rendered document view

---

## Features Guide

### Opening Files

**Method 1: Menu/Toolbar**
- Click "Open" in the toolbar, or use File → Open Document (⌘O)
- Select any `.md` or `.txt` file

**Method 2: Drag & Drop**
- Drag a markdown file from Finder onto the document area

**Method 3: Recent Files**
- Click "Recent Files" in the sidebar to see previously opened documents

### Document Viewing

The right pane renders markdown with full formatting:
- **Headings** — Sized and bolded (H1 through H6)
- **Bold/Italic** — Inline `**bold**` and `*italic*` rendered properly
- **Code blocks** — Monospaced font with gray background and language label
- **Inline code** — Gray background highlight
- **Blockquotes** — Blue left border with italic text
- **Lists** — Bullet points (•) and numbered items
- **Links** — Blue underlined text (clickable)
- **Horizontal rules** — Divider lines

### Outline Navigation

1. Select "Outline" in the sidebar
2. The middle pane shows all headings from the document
3. **Click any heading** → the document scrolls to that section
4. Use the filter field to search within headings

### Search

1. Select "Search" in the sidebar
2. Type a search term and press Enter
3. Results show with line numbers and context
4. Click a result to navigate to it in the document

### Source Editor

1. Select "Source" in the sidebar
2. The middle pane shows the raw markdown text
3. Edit the content directly
4. Click "Save" (or ⌘S) to save changes and refresh the rendered view
5. A "Modified" indicator appears when there are unsaved changes

### Multiple Documents

- Open multiple files — each appears as a tab above the document view
- Click tabs to switch between documents
- Right-click a tab or use "Open Documents" in the sidebar for management
- Close individual tabs with the × button

### File Comparison

1. Open a document
2. Click the compare button (↔) in the toolbar, or use Edit → Compare with File (⇧⌘D)
3. Select a second file to compare
4. Both documents display side-by-side with formatted rendering
5. Click "Exit Compare" to return to normal view

### Themes & Appearance

**Via Sidebar:**
- Select "Themes" to see all theme options
- Click a theme to apply it immediately

**Via Settings:**
- Select "Settings" in the sidebar
- Adjust theme, font size, high contrast, and reduce motion

**Via Menu:**
- Format → Theme → select theme
- Format → Increase/Decrease/Reset Font Size
- View → Show Line Numbers (⇧⌘L)

### Line Numbers

- Toggle via View → Show Line Numbers (⇧⌘L)
- Or enable in Settings → Editor → "Show line numbers"
- Line numbers appear in a gutter on the left side of the document

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Document | ⌘O |
| Close Document | ⌘W |
| Find in Document | ⌘F |
| Compare with File | ⇧⌘D |
| Show Line Numbers | ⇧⌘L |
| Zoom In | ⌘+ |
| Zoom Out | ⌘- |
| Actual Size | ⌘0 |
| Increase Font | ⇧⌘= |
| Decrease Font | ⇧⌘- |

---

## Testing Checklist

### Document Loading
- [ ] Open a small .md file (<10KB) — loads instantly
- [ ] Open a large .md file (>500KB) — loads within 2 seconds
- [ ] Open a file with complex formatting (tables, code, lists)
- [ ] Open multiple files — tabs appear
- [ ] Switch between tabs — content updates
- [ ] Close a tab — remaining tabs work correctly
- [ ] Drag and drop a file onto the window

### Rendering Quality
- [ ] Headings display at correct sizes (H1 largest, H6 smallest)
- [ ] Bold text renders bold
- [ ] Italic text renders italic
- [ ] Inline code has gray background
- [ ] Code blocks have border, background, and language label
- [ ] Blockquotes have blue left border
- [ ] Unordered lists show bullet points
- [ ] Ordered lists show numbers
- [ ] Links are blue and underlined
- [ ] Horizontal rules display as dividers

### Outline Navigation
- [ ] Outline shows all headings from the document
- [ ] Heading levels are visually distinct (indentation, color dots)
- [ ] Clicking a heading scrolls the document to that section
- [ ] Filter field narrows the outline list

### Search
- [ ] Typing a query returns results
- [ ] Results show line numbers and context
- [ ] Clicking a result navigates to it
- [ ] Empty query shows no results
- [ ] Non-matching query shows "No results"

### Source Editor
- [ ] Shows raw markdown content
- [ ] Content is editable
- [ ] "Modified" indicator appears on edit
- [ ] Save button writes changes to file
- [ ] Rendered view updates after save

### Comparison
- [ ] Compare button opens file picker
- [ ] Two documents display side-by-side
- [ ] Both sides render formatted markdown
- [ ] "Exit Compare" returns to normal view

### Themes & Settings
- [ ] Theme picker shows all options (Light, Dark, System, Custom, High Contrast)
- [ ] Selecting a theme changes the document appearance
- [ ] Font size slider adjusts text size in real-time
- [ ] High contrast toggle changes colors
- [ ] Line numbers toggle works

### Performance
- [ ] Scrolling is smooth (no stuttering)
- [ ] Switching tabs is instant
- [ ] Search results appear quickly (<1 second)
- [ ] Large documents don't freeze the UI

---

## Known Limitations

- iOS target exists in source but requires Xcode to build (not buildable via SPM on macOS)
- Image rendering shows placeholder (no network image loading)
- Table rendering uses the parser's text output (not grid layout)
- No syntax highlighting colors in code blocks (monospaced only)
- Compare mode shows formatted text, not a diff view

---

## Troubleshooting

**App won't open a file:**
- Ensure the file has `.md` or `.txt` extension
- Check file permissions in Finder → Get Info
- Try dragging the file instead of using the Open dialog

**Document appears blank:**
- Check if the file is empty
- Try closing and reopening the file
- Check the Source editor to see if raw content is present

**Settings don't persist:**
- Settings are stored in UserDefaults
- Rebuilding the app may reset the defaults suite
- Use the Settings panel to re-apply preferences
