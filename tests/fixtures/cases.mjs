const colors = {
  bg: [18, 22, 28],
  bgPanel: [38, 49, 59],
  bgAccent: [66, 57, 43],
  bgLight: [212, 216, 222],
  text: [226, 231, 238],
  textMuted: [104, 112, 120],
  textDark: [36, 41, 48],
  green: [118, 201, 147],
  yellow: [226, 190, 92]
};

const terminalColors = [
  [0, 0, 0],
  [205, 49, 49],
  [13, 188, 121],
  [229, 229, 16],
  [36, 114, 200],
  [188, 63, 188],
  [17, 168, 205],
  [229, 229, 229],
  [102, 102, 102],
  [241, 76, 76],
  [35, 209, 139],
  [245, 245, 67],
  [59, 142, 234],
  [214, 112, 214],
  [41, 184, 219],
  [255, 255, 255]
];

const defaultOptions = {
  originY: 4,
  tolerance: {
    perChannel: 2,
    maxMismatchRatio: 0.001
  },
};

function colorBlockShapes(row, blockWidthCells) {
  return terminalColors.map((color, index) => ({
    type: "rect",
    col: 1 + index * (blockWidthCells + 1),
    row,
    w: blockWidthCells,
    color
  }));
}

const blockGlyphPatterns = {
  "▛": ["upperLeft", "upperRight", "lowerLeft"],
  "▀": ["upperLeft", "upperRight"],
  "▜": ["upperLeft", "upperRight", "lowerRight"],
  "▐": ["upperRight", "lowerRight"],
  "▟": ["upperRight", "lowerLeft", "lowerRight"],
  "▄": ["lowerLeft", "lowerRight"],
  "▙": ["upperLeft", "lowerLeft", "lowerRight"],
  "▌": ["upperLeft", "lowerLeft"]
};

function blockGlyphShapes(row, startCol, color) {
  return Object.entries(blockGlyphPatterns).map(([char, pattern], index) => ({
    type: "block",
    char,
    pattern,
    col: startCol + index,
    row,
    color
  }));
}

export const shaderSnapshotCases = [
  {
    ...defaultOptions,
    name: "vertical-bar-cell-background",
    description: "Full-height vertical bars should not turn the rest of their cells into gradient text.",
    columns: 10,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 4, row: 1, cols: 3, rows: 3, color: colors.bgPanel },
      { col: 7, row: 0, cols: 2, rows: 2, color: colors.bgAccent }
    ],
    shapes: [
      { type: "glyph", col: 1, row: 3, color: colors.text },
      { type: "vline", col: 2, row: 2, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 5, row: 2, color: colors.green, thicknessPx: 2 },
      { type: "vline", col: 6, row: 1, color: colors.text, thicknessPx: 2 },
      { type: "glyph", col: 8, row: 1, color: colors.yellow }
    ]
  },
  {
    ...defaultOptions,
    name: "box-drawing-grid",
    description: "Box drawing borders combine full-height and full-width strokes across neighboring cells.",
    columns: 12,
    rows: 6,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 2, row: 1, cols: 7, rows: 4, color: colors.bgPanel },
      { col: 9, row: 1, cols: 2, rows: 4, color: colors.bgAccent }
    ],
    shapes: [
      { type: "hline", col: 2, row: 4, cols: 7, color: colors.text, thicknessPx: 2 },
      { type: "hline", col: 2, row: 1, cols: 7, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 2, row: 1, rows: 4, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 8, row: 1, rows: 4, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 10, row: 1, rows: 4, color: colors.yellow, thicknessPx: 2 },
      { type: "glyph", col: 4, row: 3, color: colors.green },
      { type: "glyph", col: 6, row: 2, color: colors.text }
    ]
  },
  {
    ...defaultOptions,
    name: "hard-background-boundary",
    description: "Nearby probes should not blend across a hard vertical background boundary.",
    columns: 12,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 6, row: 0, cols: 6, rows: 5, color: colors.bgLight },
      { col: 0, row: 2, cols: 3, rows: 1, color: colors.bgPanel }
    ],
    shapes: [
      { type: "glyph", col: 4, row: 2, color: colors.text },
      { type: "vline", col: 5, row: 2, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 6, row: 2, color: colors.textDark, thicknessPx: 2 },
      { type: "glyph", col: 7, row: 2, color: colors.textDark },
      { type: "glyph", col: 10, row: 3, color: colors.textDark }
    ]
  },
  {
    ...defaultOptions,
    name: "low-contrast-text",
    description: "Low-contrast glyphs should remain stable while normal text still gets the row gradient.",
    columns: 10,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: [34, 37, 42],
    iBackgroundColor: [34, 37, 42],
    fills: [
      { col: 1, row: 1, cols: 8, rows: 3, color: [42, 45, 50] }
    ],
    shapes: [
      { type: "glyph", col: 2, row: 2, color: colors.textMuted },
      { type: "vline", col: 4, row: 2, color: colors.textMuted, thicknessPx: 2 },
      { type: "glyph", col: 6, row: 2, color: colors.text },
      { type: "hline", col: 7, row: 2, cols: 2, color: colors.text, thicknessPx: 2 }
    ]
  },
  {
    ...defaultOptions,
    name: "cursor-origin-offset",
    description: "Column-center sampling should stay aligned when the terminal grid origin is not zero.",
    columns: 9,
    rows: 4,
    cellWidth: 11,
    cellHeight: 19,
    originX: 5,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 3, row: 0, cols: 4, rows: 4, color: colors.bgPanel }
    ],
    shapes: [
      { type: "glyph", col: 1, row: 2, color: colors.text },
      { type: "vline", col: 3, row: 2, color: colors.text, thicknessPx: 2 },
      { type: "vline", col: 5, row: 1, color: colors.green, thicknessPx: 2 },
      { type: "glyph", col: 7, row: 1, color: colors.yellow }
    ]
  },
  {
    ...defaultOptions,
    name: "color-blocks",
    description: "Solid ANSI color blocks should stay stable at one-cell and two-cell widths.",
    columns: 49,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    shapes: [
      ...colorBlockShapes(1, 1),
      ...colorBlockShapes(3, 2)
    ]
  },
  {
    ...defaultOptions,
    name: "light-background-underscore",
    description: "Dark underscores on ANSI white app backgrounds should use the cell fill as the background.",
    columns: 10,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 2, row: 1, cols: 6, rows: 3, color: [229, 229, 229] }
    ],
    shapes: [
      { type: "glyph", col: 3, row: 2, color: colors.textDark },
      { type: "underscore", col: 5, row: 2, color: colors.textDark },
      { type: "glyph", col: 6, row: 2, color: colors.textDark }
    ]
  },
  {
    ...defaultOptions,
    name: "off-white-background-dark-text",
    description: "Very dark text-like glyphs on an off-white app background should only gradient the glyph pixels.",
    columns: 12,
    rows: 5,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 1, row: 1, cols: 10, rows: 3, color: [227, 227, 225] }
    ],
    shapes: [
      { type: "glyph", variant: "e", col: 2, row: 2, color: [10, 10, 10] },
      { type: "glyph", variant: "i", col: 4, row: 2, color: [10, 10, 10], heightScale: 0.55, yOffset: 1.0 },
      { type: "glyph", variant: "dot", col: 5, row: 2, color: [10, 10, 10], heightScale: 0.45, yOffset: 1.0 },
      { type: "glyph", variant: "colon", col: 6, row: 2, color: [10, 10, 10], heightScale: 0.65, yOffset: 0.55 },
      { type: "glyph", variant: "t", col: 8, row: 2, color: [10, 10, 10], heightScale: 0.8, yOffset: 0.25 },
      { type: "glyph", variant: "n", col: 10, row: 2, color: [10, 10, 10], heightScale: 0.75, yOffset: 0.55 }
    ]
  },
  {
    ...defaultOptions,
    name: "underlined-descender-background",
    description: "An underlined descender should not make side background strips look like text.",
    columns: 8,
    rows: 4,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 2, row: 1, cols: 3, rows: 2, color: colors.bgPanel }
    ],
    shapes: [
      { type: "underlinedDescender", col: 3, row: 1, color: [41, 184, 219] }
    ]
  },
  {
    ...defaultOptions,
    name: "partial-block-glyph-backgrounds",
    description: "Partial block glyphs should not make their empty cell regions look like gradient text.",
    columns: 12,
    rows: 4,
    cellWidth: 12,
    cellHeight: 20,
    backgroundColor: colors.bg,
    iBackgroundColor: colors.bg,
    fills: [
      { col: 1, row: 1, cols: 10, rows: 2, color: colors.bgPanel }
    ],
    shapes: blockGlyphShapes(1, 2, [41, 184, 219])
  }
];
