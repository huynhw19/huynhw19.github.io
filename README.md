# ConfigKit — Mobileconfig Studio

ConfigKit is a lightweight, browser-based demo for exploring Apple configuration profile payloads and building a basic Wi-Fi `.mobileconfig` profile.

## What’s on the site

- **Wi-Fi profile builder** — enter a profile name, network SSID, security type, and (when needed) password to generate and download a profile.
- **Profile examples** — browse sample payloads, including device information and a Home Screen web clip.
- **More mobileconfig examples** — visit [`examples.html`](examples.html) for illustrative Wi-Fi, web clip, passcode policy, restrictions, and encrypted DNS payload fragments.
- **Interface demos** — sample sign-in, sign-up, and newsletter forms. These are front-end demonstrations and do not connect to an account or mailing-list service.

## Run locally

This is a static website. Open `index.html` in a browser, or serve the repository directory with any static file server. No build step or dependencies are required.

## Privacy and profile safety

The Wi-Fi profile builder creates the file in your browser; profile data is not uploaded to a server. A generated profile is **not signed**. Treat any Wi-Fi password embedded in a profile as sensitive, and review a profile’s contents and payload settings before installing it. The examples page contains illustrative payload fragments, not complete installable profiles; required keys, supported settings, and device-management requirements can vary by operating-system version and deployment method.

This project is an independent demo and is not affiliated with Apple. Consult Apple’s current configuration profile documentation and your organization’s administrator before deploying profiles.
