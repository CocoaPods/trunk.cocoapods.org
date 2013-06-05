# Console

You can boot into the app with a REPL by making sure all the environment
variables are exported and loading up the app:

    source .powenv
    bundle exec irb -I. -r app/controllers/app.rb
