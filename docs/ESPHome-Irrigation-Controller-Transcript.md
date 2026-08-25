# ESPHome Irrigation Controller with Display

**Channel:** Vaclav Chaloupka
**Published:** 2022-09-11 · **Length:** 22:44
**URL:** https://www.youtube.com/watch?v=o5xXDPaaR2U

*Cleaned-up transcript. Auto-generated captions, de-duplicated and lightly edited for punctuation, capitalization and obvious speech-to-text errors. Wording is otherwise the speaker's.*

---

## Intro

Hey, what's up, this is Vaclav. So I'm revisiting parts of my home automation kit I did over the last five years — they're becoming obsolete — and refactoring them to bring them up to date with the current state of development. I made an overview of what's coming and why; if you didn't see it, the link is in the corner. So with that, I can get straight to it.

I'm making two videos about that. Today I will revisit the irrigation controller, which is made of a Sonoff 4-channel Pro with a Nextion color display. This is quite a popular project on the internet, and I'm not going to change the solution architecture overall — the hardware will still stay, and it will still run ESPHome as it does today — but I will update it to use the ESPHome native sprinkler controller, and I will show you three different flavors of this.

The second project is similar. It's with time-based shade actuators. That one was made in Arduino and I moved it to ESPHome, and I'm making a separate video about it to keep the videos focused.

## What the ESPHome sprinkler controller gives you

So, the sprinkler controller. This is a new addition to the last ESPHome release. The way it works is: you create a controller and you can add a number of valves, or zones, to it, represented by ESPHome switches. Then you can launch the program and it will automatically cycle through all the zones. Or you can run individual valves one by one if you want. Or you can even create a custom queue and run it forward, or in reverse, or multiple times — so you can play with that.

The beauty of it is you can configure a lot of parameters. You can configure a run duration for each valve, but also a multiplier for the whole controller or for each valve — for example, based on the soil moisture, the weather, or the time of year. You can also enable or disable individual zones.

One of the great features it has is that you can configure a pump switch across the controller, or for each valve, so that will automatically start the pump at the beginning of the cycle and stop it at the end. I actually use it not for a pump, but I added a solenoid valve that shuts off the water supply, so that it is not under pressure when it's not used, and it's drained and blocked in the winter.

Then you can configure and adjust delays or overlaps — adjust the timing of the individual valves and the pump. That can be used if the irrigation uses pressure to control the thing, and to avoid banging if you have longer lines. I don't use it and I will not show it to you, but you know it can be added very simply — just check the documentation and you can just add it on.

It also supports latching valves that need pulse control. Again, I'm not going to use it, but it's very easy — it's just one line of config, you can just edit it.

In this video I will configure one controller, but you could also configure multiple controllers on a single device. So if you have different parts of a garden that each have different zones and sequences and run separately, you could do that as well. It's all nicely documented on the ESPHome site. I'm not going to explain each individual parameter, but let me show you what I did, what I used, and how it changed from what it was before.

## The old solution

First, what was used before. It was a completely custom solution that was using global variables as timers. So I had four global variables that were used to count the remaining time, and there were four other global variables that were used for the duration — the initial value for the timers.

Then there was a script. When the valve was opened — so there was a GPIO relay here, there were switches, one for each valve — when it was turned on it would set the remaining time to the value of the duration. So these are the two variables that you saw before.

And then there was an interval, which was every five seconds looking at the state of the relay. If the relay was on, it was decrementing the remaining time by five seconds, and if the time reached zero it would shut off the valve. So this is where we're coming from.

## The new configuration

Now, what has changed. All the global variables for the duration and for the timers, and the interval checking the state of the valves every five seconds and decrementing the timers — it's all gone. We don't need that anymore. It's all been replaced by this sprinkler controller.

It's got an ID, because we use it in scripting and automation from the physical buttons to initiate the cycles or start the individual valves — I'm going to get to that. And then it's got an auto-advance switch configured, so we will see that from the Home Assistant screen.

And then it's got those four valves. Each valve has this relay — those relays are the GPIO switches as before — and each of those valves has a name configured, so I can see it in the Home Assistant screen, and they have a default duration, and we can change that if we want to.

With this I will be able to control that from Home Assistant, trigger it by automation — for example, at a specific time — and start the irrigation cycle. So that's all it needs: those 15 lines of code.

## Keeping the physical buttons working

But I want to do more, right? I would like to still be able to control it manually from the Sonoff, by the buttons. For that I still have the GPIO binary sensor, and from these I would like to toggle the valves — I would like to turn them on and off.

But the valves are now managed by the controller. We wouldn't turn them on and off manually, because the controller wouldn't know what's going on. And the controller doesn't have any toggle operation to turn it on and off. In fact, maybe it does, but if I did that I would start the whole controller, whereas here I'm targeting the individual valve, which is represented by the button.

So what I'm doing here is: if the valve is off, I'm not starting the whole cycle, but I am starting a single-valve program. I'd like to turn this single valve on, and it will then automatically turn off after the duration time has expired. So this is what I'm doing when the valve is off. When the valve is on, then I'd like to turn it off — so here I'm just shutting down the sprinkler controller. So these are the buttons.

## The display

Then we also have the display. Here what I'm doing is checking each button, and if it's on, then I'm going to read the remaining time from the controller. The remaining time variable will show the remaining time of the currently running valve, and if there is a remaining time, I'm going to format it and display it on the Nextion display.

Now, if you noticed, in the old design I was always refreshing all the values — so every five seconds I was either showing the time, or I was setting the value to an empty string. I have changed that a little bit, so I'm only updating the display when I have to update it. What I have done is: when the relay turns off, I'm going to set the text to an empty string, based on the state change. I don't keep updating it every five seconds; I only do it when the cycle is finished.

The same thing I do with the sensor values. I have the sensors for the rain today, rain in the last three days, and whether the irrigation has run in the last 24 hours, and I'm only setting that when the sensor value — as received through the API from Home Assistant — is updated. So with that, the display is much easier. I'm only using it to update the remaining time every five seconds if the valve is open.

## Buttons on the Nextion

Then I also have the buttons on the Nextion. There is a button to launch an irrigation program, and I used to have that before as well, but what it was, I was calling a script inside Home Assistant. So Home Assistant was taking care of sequencing the valves and the timing, and it was running them one by one. I don't need to do it anymore. So when I push the button, I'm only calling *sprinkler start full cycle* with the controller, and it'll do everything automatically on the device.

I have a second program that I don't use for the full cycle. What I do here is I set up a queue — I put there two valves, so the first and second valve, each for 900 seconds — and then I start the sprinkler queue from there.

## Summary of the basic version

So to summarize: it has greatly simplified the configuration of the controller, but it has complicated the configuration of those GPIO switches a little bit, because I can't just toggle it. And I'm also missing the possibility to set up the timers — in the original design I had an API set up with services that allowed me to set the times.

## The advanced configuration

But wait — I have an advanced configuration where I'm addressing both of those issues.

First, I have created a file where I have concentrated a few helper functions, if you will. So this whole reading of the remaining time, and formatting it, and showing it in the right format — nah, I have created a function for it. So I can then just call *set component text*, sprinkler time, and then the remaining time of the controller. So it makes it much easier — it's much shorter. Completely optional.

I have done the same with the binary sensors. As you know, previously I used to have this whole "if the switch is off do this, otherwise do that." I have greatly simplified it — I just call *toggle relay and controller*, and I have created a function that is doing the logic in the file. So it doesn't do anything different, I have just simplified it, so I have it on one line.

To use those helpers, you need to take this `irrigation.h` file and copy it into your Home Assistant config in the ESPHome directory. Then this file is referenced by the configuration script: in the `esphome:` section there is an extra line, `includes: irrigation.h`. So this is the name of the file, and then those helpers are available for you to use.

### Durations as numbers

So these are cosmetic changes, but more importantly, I set up those numbers here that allow me to control the duration from Home Assistant. There are four numbers with the durations, and what they do is return the current valve duration, and when I set it from Home Assistant I call the function *set valve run duration*.

So if I go to the devices and I search for it, this is how it shows on the device page. You can see the four numbers with the durations, and they show the actual current duration that is set up on the device, and if I change that it'll automatically change it on the device.

And then I have those four valves, and I can turn them on to start the single-valve program from Home Assistant. Or I can turn on this switch, "the grass," which is going to start a full cycle, basically turning on sequentially all of those three switches. I say three, not four, because I actually have two controllers configured on my device — I'll show you in a second. One for what I call the grass, and then a separate one with sockets that are normally not used in the full cycle. So I have two different controllers set up on a single device.

### What changed, graphically

So what's the big deal? If I graphically would like to show you what has changed: in this file, everything shown in red has been removed, and everything shown in green has been changed or added.

You can see clearly that this whole global section has been removed — we don't need it anymore — as well as, back here, this interval section, which was pretty much running the whole logic and driving the controller. This is not necessary anymore, we don't have it.

We have also removed all of those services that were setting up the timers, and in the advanced script that has been replaced by the numbers, so we don't need to call any services for that. This is all done seamlessly.

I've also greatly improved the display. It has nothing to do with the irrigation controller as such, but I do it much better now: I only update the timers when I need to, and I have moved the actual updates to the actual sensors, so they're only updated when they change.

And finally, the old solution was relying on Home Assistant's services, and now it can be done natively by the device. So this is a summary of all the major changes.

## My actual implementation

So these are the two versions I shared on GitHub. One is easy to understand, the other one is easy to use and kind of neat.

Now, what I use is 90% similar to the second one, to the advanced config, but there are a few further customizations I made. The reason I didn't add them to GitHub is that I think it's a little bit too specific and it's making it a little bit too complicated for general use. But let me show it to you anyhow, in case you like it and can get inspired.

Briefly, what is different in my actual implementation — as I said, it's a little bit more complex. What I did is I used push buttons for the actual sprinklers on the display. So it'll show when the valve is open, it'll show it on the display, and I can also push the button to initiate the single-valve operation from there as well. So it's kind of redundant to the physical buttons on the side of the Sonoff, but for example, if you use another platform — if you don't use the Sonoff 4-channel — and you would like to control it from the display, this is what you can do.

So what I do is, when ESPHome is started on boot, I'm reading the state of the different relays and setting the value of the four buttons accordingly.

### The pump / solenoid valve

I also mentioned I use a "pump," which is in fact a solenoid valve that shuts the water coming into the irrigation on and off. So I'm refreshing that initially on the state as well. But I do not control this pump directly from this device — it is controlled by another device connected to Home Assistant.

So what I have done is, I have configured this binary sensor connected through the Home Assistant platform — so through the API — and then I'm showing the state of this pump on the display as well. When the state changes I will update this button on the display from active to inactive. And when I push the button, then I have a switch here — when I push the button I will control the solenoid valve accordingly.

But to do that I need to configure a switch for the water pump, because here this was only a binary sensor that was showing the current state. So I have configured a switch, and I use a template switch, and the template switch, to return the state, is actually using this binary sensor here. So it's reading this binary sensor to return the state. And then we'd like to turn it on or turn it off, and I call the Home Assistant service to turn it on and off.

So it's a little bit complicated. It would have been much easier if I could control the solenoid directly from the device, but as I said, it's from a different part of the house, so I do it through Home Assistant. So it's a little bit cumbersome, which is the reason I did not include it in the template — because it would make it confusing and too complicated.

So that's the pump. And here in the sprinkler, I mentioned I have two controllers, one for the grass and one for the sockets, and in each of those I'm actually using this pump switch. So this is the ID of the switch I was just showing. When the valve opens it'll automatically open the solenoid valve and let the water inside the irrigation. So this is another change here.

### The touchscreen valve buttons — and the bug

So, where was I? I was talking about the buttons — the binary buttons — that I'd like to show the state, and I'd like to also use to turn the valve on and off.

So I have here the switches for the four buttons, and this is a Nextion platform button — so this is the touchscreen button, and this is the component name. What it does is, if I turn it on, I will call this *conditional on* — remember, we have created this helper function. So it's checking whether the relay is off, and if it's off then it'll turn it on, and if it's on it'll shut down the controller.

And then, to update the state of the button, what I do is, when the actual relay changes state, I do not only show the time but I also update the state of this button. So when I turn on the valve it'll set the value of this button to one, and when it turns off I will set it to zero.

Which is what got me into trouble initially. I spent quite a bit of time troubleshooting it, because it's kind of creating a positive loop: I'm setting the button here on and off, and then here I'm running a script when it turns on and off.

So what happened was, when I set it on here, it'll call this function, and in this function I started a single-valve operation. So if it was turned on as part of a full-cycle operation, this button would actually override it and it would automatically start a single-valve operation. At the same time, when it turns off, it'll shut down the controller here.

Anyhow — initially I set it simply to turn the valve on when the button turned on, and shut down the controller when it turned off. And then I spent a day trying to figure out why the cycle didn't work and always ended after the first zone. I thought the sprinkler controller was rubbish, and then I figured out it's me being stupid: when the first zone finished, it turned off the Nextion binary switch, and it shut down the controller. You get it, right?

So this single cosmetic change I wanted made it quite a bit more complicated. I'm thinking about a theory of diminishing returns now — which is the reason why I didn't include that on GitHub, because then people would probably say this is unnecessary, too much work for very little benefit.

### Scripts and the weather screen

So to finish it: I have done one more thing. I've created an API so I can start different programs directly from Home Assistant, and for that I have created scripts. There is one script which is essentially starting a full cycle — I didn't have to create a script because this is a single command, but anyhow. I have created a second script which is adding those two valves into the queue and then starting the queue. So this way I could create, using the script, different custom programs. So it's kind of neat.

Finally, I added an additional screen with the weather forecast and temperatures, because it's quite convenient for me in the place where it is. It's really taken from the weather station display that is also posted on GitHub, and it works for me. But I didn't really add it to the project, because it has nothing to do with the irrigation control. But at least you can see you can use it as a puzzle, and take parts and just add them and combine them.

## Outro

So what do you say, do you like it? I have updated the project on GitHub, so you can still see it there. And with that I will end the video here, but you can continue in the next one with the ESPHome window blind. Bye.
