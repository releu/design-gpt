# Authentication Screen

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-2

---

## Purpose

This is the screen shown to unauthenticated users when they visit the application. It provides a sign-in prompt that initiates the Auth0 login flow. No application content (prompt area, design system selector, previews) is visible in this state.

---

## Layout

### Structure

- Full viewport, centered both horizontally and vertically
- Background: fill
- A single card/icon centered on screen

---

## Components

### Wave icon / Sign-in prompt

- **Position**: Dead center of the viewport (flexbox centering)
- **Appearance**: A large hand-wave icon displayed on a white rounded-rectangle card
- **Card size**: Approximately 120px x 120px
- **Card styling**:
  - Background: white
  - Border-radius: `--radius-md` (16px)
  - Subtle shadow: `0 2px 12px rgba(0,0,0,0.06)`
- **Icon**: Hand wave image/emoji, roughly 80px, centered inside the card
- **Behavior**: The card is clickable -- clicking it initiates the Auth0 login redirect

### Additional elements (recommended from spec)

The mockup shows only the wave icon, but the feature spec (`01-authentication.feature`) states the user should see a "sign-in prompt." Developers should include:

- A text label below the card: **"Sign in to continue"** or similar
  - Font: darkgray, centered
  - Margin-top from card: `--sp-3` (16px)
- Optionally, a "Sign in" button below the label
  - Pill-shaped, black background, white text
  - Same style as the "generate" button

---

## States

| State           | Description                                                   |
|-----------------|---------------------------------------------------------------|
| Default         | Wave icon card centered, waiting for user interaction          |
| Loading         | After click: card could show a subtle pulse animation or the browser redirects to Auth0 |
| Auth0 redirect  | Browser navigates to Auth0 hosted login page (external)       |
| Return          | After successful login, Auth0 redirects back and the app loads the main view (see `04-home-new-design.md`) |
| Error           | If Auth0 returns an error, display a toast or inline message below the card |

---

## Interactions

| Action              | Result                                                      |
|---------------------|-------------------------------------------------------------|
| Click wave card     | Initiate Auth0 login redirect                               |
| Auth0 success       | Redirect to home page; app container becomes visible         |
| Auth0 failure       | Show error message; remain on authentication screen          |

---

## Navigation

| From                | To                                                           |
|---------------------|-------------------------------------------------------------|
| Any unauthenticated URL | This screen (route guard redirects here)               |
| Successful login    | Home / New Design page (`04-home-new-design.md`)             |

---

## Spec Coverage

- `01-authentication.feature`: "Unauthenticated user sees sign-in prompt" -- this screen satisfies that scenario
- `01-authentication.feature`: "No application content should be shown" -- only the wave icon is visible; no prompt area, no design system selector
