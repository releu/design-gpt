export const components = {
  DesignSelector: {
    figmaId: "1:282", width: 320, height: 48,
    props: { designs: [{ id: "1", name: "My Design" }], modelValue: "new" },
  },
  MoreButton: {
    figmaId: "2:428", width: 48, height: 48,
    props: {},
  },
  Module: {
    figmaId: "1:33", width: 462, height: 322,
    props: { label: "label" },
  },
  Preview: {
    figmaId: "1:56", width: 462, height: 322,
    props: {},
    special: "preview-empty",
  },
  Header: {
    figmaId: "1:633", width: 1053, height: 48,
    props: {},
    special: "header-with-slots",
  },
  ModuleChat: {
    figmaId: "1:971", width: 320, height: 400,
    props: { messages: [
      { id: 1, author: "user", content: "short text" },
      { id: 2, author: "designer", content: "short text" },
      { id: 3, author: "user", content: "long text long text long text long text long text long text long text long text long text long text" },
      { id: 4, author: "designer", content: "long text long text long text long text long text long text long text" },
      { id: 5, author: "user", content: "long text long text long text long text long text long text long text long text long text long text long text" },
    ], designId: "1" },
  },
  ModuleCode: {
    figmaId: "2:420", width: 680, height: 480,
    props: { modelValue: '<h1>Hedy Lamarr\'s Todos</h1>\n<img\n  src="https://i.imgur.com/yXOvdOSs.jpg"\n  alt="Hedy Lamarr"\n  class="photo"\n>\n<ul>\n    <li>Invent new traffic lights\n    <li>Rehearse a movie scene\n    <li>Improve the spectrum technology\n</ul>', language: "markdown" },
  },
  ModuleContentPrompt: {
    figmaId: "2:342", width: 320, height: 400,
    props: { modelValue: "", placeholder: "describe what you want to create" },
  },
  ModuleContentDesignSystem: {
    figmaId: "2:350", width: 320, height: 400,
    props: { libraries: [
      { id: "1", name: "common/depot" },
      { id: "2", name: "releu/depot" },
      { id: "3", name: "andreas/cubes" },
    ], modelValue: "1" },
  },
  ModuleContentAIEngine: {
    figmaId: "2:284", width: 561, height: 42,
    props: { disabled: false },
  },
  ModeSelector: {
    figmaId: "1:247", width: 260, height: 48,
    props: { modelValue: 0 },
    variants: [
      { name: "selected-1", figmaId: "1:247", props: { modelValue: 0 } },
      { name: "selected-2", figmaId: "2:529", props: { modelValue: 1 } },
    ],
  },
  PreviewSelector: {
    figmaId: "1:594", width: 300, height: 48,
    props: { modelValue: "phone" },
    variants: [
      { name: "selected-1", figmaId: "1:594", props: { modelValue: "phone" } },
      { name: "selected-2", figmaId: "1:917", props: { modelValue: "desktop" } },
      { name: "selected-3", figmaId: "1:924", props: { modelValue: "code" } },
    ],
  },
  ModuleDesignSystem: {
    figmaId: "17:378", width: 540, height: 358,
    props: { designSystem: null },
    special: "module-design-system",
    variants: [
      { name: "view-new", figmaId: "17:378", props: { designSystem: null } },
      { name: "view-overview", figmaId: "2:542", props: { designSystem: { name: "Depot", libraries: [{ id: 1, name: "Depot Lib" }, { id: 2, name: "Super icons" }] } } },
      { name: "view-component", figmaId: "2:579", props: { designSystem: { name: "Depot", libraries: [{ id: 1, name: "Depot Lib" }, { id: 2, name: "Super icons" }] } } },
    ],
  },
};

export const frames = {
  home:                     { figmaId: "1:965",  width: 1280, height: 760 },
  "design-phone":           { figmaId: "1:966",  width: 1280, height: 760 },
  "design-desktop":         { figmaId: "1:967",  width: 1280, height: 760 },
  "design-code":            { figmaId: "1:968",  width: 1280, height: 760 },
  "design-settings":        { figmaId: "2:475",  width: 1280, height: 760 },
  "home-new-design-system": { figmaId: "17:204", width: 1280, height: 760 },
};

// Mock data for frame compositions
export const mockData = {
  chatMessages: [
    { id: 1, author: "user", content: "short text" },
    { id: 2, author: "designer", content: "short text" },
    { id: 3, author: "user", content: "long text long text long text long text long text long text long text long text long text long text" },
    { id: 4, author: "designer", content: "long text long text long text long text long text long text long text" },
    { id: 5, author: "user", content: "long text long text long text long text long text long text long text long text long text long text long text" },
  ],
  libraries: [
    { id: "1", name: "common/depot" },
    { id: "2", name: "releu/depot" },
    { id: "3", name: "andreas/cubes" },
  ],
  codeContent: '<h1>Hedy Lamarr\'s Todos</h1>\n<img\n  src="https://i.imgur.com/yXOvdOSs.jpg"\n  alt="Hedy Lamarr"\n  class="photo"\n>\n<ul>\n    <li>Invent new traffic lights\n    <li>Rehearse a movie scene\n    <li>Improve the spectrum technology\n</ul>',
  dsLibraries: [
    {
      id: 1, name: "Depot Lib", status: "ready", loading: false, error: null, progress: null,
      components: [
        { id: 1, name: "component name", type: "component" },
        { id: 2, name: "component name", type: "component" },
        { id: 3, name: "component name", type: "component" },
        { id: 4, name: "component name", type: "component" },
      ],
    },
    {
      id: 2, name: "Super icons", status: "ready", loading: false, error: null, progress: null,
      components: [
        { id: 5, name: "component name", type: "component" },
        { id: 6, name: "component name", type: "component" },
      ],
    },
  ],
};
