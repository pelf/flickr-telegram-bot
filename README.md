Start by caching the photos locally (in Redis). This saves requests and speeds up response times:

``` bash
$ ruby cache_photos.rb
```

To run the bot that responds to commands:

``` bash
# set "mode" to "live" to use live credentials or leave it out to use test credentials
$ ruby run_bot.rb [mode]
```

To run the "time hop" service:

``` bash
# set "mode" to "live" to use live credentials or leave it out to use test credentials
$ ruby timehop_bot_service.rb [mode]
```

