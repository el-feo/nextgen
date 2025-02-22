# Examples

The Rails apps in this directory were all generated by `gem exec nextgen create` with various interactive menu items chosen.

## default

[`examples/default`](./default) was created by choosing the default option for every question, and declining all optional Nextgen enhancements. This generally represents the default Rails "omakase" experience with a [base](../lib/nextgen/generators/base.rb) level of improvements.

```
What version of Rails will you use?
‣ 8.0.1
  edge (8-0-stable)
  main (8.1.0.alpha)

Which database?
‣ SQLite3 (default)
  PostgreSQL (recommended)
  MySQL
  More options...

What style of Rails app do you need?
‣ Standard, full-stack Rails (default)
  API only

How will you manage frontend assets?
‣ Propshaft (default)
  Vite

Which CSS framework will you use with the asset pipeline?
‣ None (default)
  Bootstrap
  Bulma
  PostCSS
  Sass
  Tailwind

Which JavaScript bundler will you use with the asset pipeline?
‣ Importmap (default)
  Bun
  ESBuild
  Rollup
  Webpack
  None

Rails can preinstall the following. Which do you need?
‣ ⬢ Brakeman
  ⬢ GitHub Actions CI
  ⬢ Kamal
  ⬢ RuboCop
  ⬢ Solid Cache+Queue
  ⬢ Thruster
  ⬡ devcontainer files

Which optional Rails frameworks do you need?
‣ ⬢ Hotwire
  ⬢ JBuilder
  ⬢ Action Mailer
  ⬢ Active Job
  ⬢ Action Cable
  ⬢ Active Storage
  ⬢ Action Text
  ⬢ Action Mailbox

Which test framework will you use?
‣ Minitest (default)
  RSpec
  None

Include system testing (capybara)?
‣ Yes (default)
  No

Which optional enhancements would you like to add?
‣ ⬡ AnnotateRb
  ⬡ BasicAuth controller concern
  ⬡ Bundler Audit
  ⬡ capybara-lockstep
  ⬡ dotenv
  ⬡ erb_lint
  ⬡ ESLint
  ⬡ Factory Bot
  ⬡ GitHub PR template
  ⬡ good_migrations
  ⬡ letter_opener
  ⬡ mocha
  ⬡ Open browser on startup
  ⬡ Overcommit
  ⬡ rack-canonical-host
  ⬡ rack-mini-profiler
  ⬡ RuboCop (nextgen custom config)
  ⬡ shoulda
  ⬡ Staging environment
  ⬡ Stylelint
  ⬡ Thor
  ⬡ VCR
```

## rspec

[`examples/rspec`](./rspec) is the same as the default example, except "RSpec" was chosen when prompted to select a test framework:

```
Which test framework will you use?
  Minitest (default)
‣ RSpec
  None
```

## vite

[`examples/vite`](./vite) shows what is generated when "Vite" is chosen as an alternative to Sprockets.

```
How will you manage frontend assets?
  Propshaft (default)
‣ Vite

Which JavaScript package manager will you use?
‣ yarn (default)
  npm
```

## all

[`examples/all`](./all) shows what is generated when all optional Nextgen enhancements are selected, including Sidekiq, Factory Bot, Bundler Audit, ESLint, and more than a dozen others. In this example, the default Kamal and Solid Cache+Queue choices have been deselected so that Tomo and Sidekiq can be installed in their place.

```
Rails can preinstall the following. Which do you need?
  ⬢ Brakeman
  ⬢ GitHub Actions CI
  ⬡ Kamal
  ⬢ RuboCop
‣ ⬡ Solid Cache+Queue
  ⬢ Thruster
  ⬡ devcontainer files

Which optional enhancements would you like to add?
‣ ⬢ AnnotateRb
  ⬢ BasicAuth controller concern
  ⬢ Bundler Audit
  ⬢ capybara-lockstep
  ⬢ dotenv
  ⬢ erb_lint
  ⬢ ESLint
  ⬢ Factory Bot
  ⬢ GitHub PR template
  ⬢ good_migrations
  ⬢ letter_opener
  ⬢ mocha
  ⬢ Open browser on startup
  ⬢ Overcommit
  ⬢ rack-canonical-host
  ⬢ rack-mini-profiler
  ⬢ RuboCop (nextgen custom config)
  ⬢ shoulda
  ⬢ Sidekiq
  ⬢ Staging environment
  ⬢ Stylelint
  ⬢ Thor
  ⬢ Tomo
  ⬢ VCR

Which JavaScript package manager will you use?
‣ yarn (default)
  npm
```
