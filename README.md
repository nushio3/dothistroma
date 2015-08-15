# Dothistroma
A load balancer that works on emacs Org mode.

![dothistroma](https://cloud.githubusercontent.com/assets/512367/9287059/7c4be516-433f-11e5-96ae-67a7186e345d.png)

With Dothistroma, you never pine any more.

You realize.

## What it does

Based on the weight assigned to each tasks, Dothistroma counts how much time resource you have had, how you have spent (`used`), and how you would have wanted to spend them (`deserv`). Based on the measurement, Dothistroma points out the single task that you should do next, so that `used` approximates `deserv`. The task is priotized in the following order.

- The task with larger (`deserv` minus `used`).
- In case of tie, the task with the larger weight.
- In case of tie, the task that is found earlier in the `.org` file.
 
## How it works

A task is _tracked_ by Dothistroma, if it is `SCHEDULED` and not `CLOSED`, and have a `WEIGHT:` line somewhere in the paragraph, as follows:

```Org
* TODO Write Readme
  SCHEDULED: <2015-05-10 Sun>
  CLOCK: [2015-05-11 Mon 18:00]--[2015-05-11 Mon 18:30] => 0:30
  
  Write README for Dothistroma.
  
  WEIGHT: 120
```

Each `CLOCK:` line in the tracked task are record of your time resource. The time resource is "consumed" in two ways: in the way you wanted to consume (`deserv`), and in the way you did consume (`used`). The total of the two ways of consumption should always match.

A tracked task _deserves_ for a time resource, if the timespan of the time resource stars no sooner than the scheduled time of the task. Each time resource is  splitted proportionally to the weight of the tasks and adds up to in the `deserv` section.

On the other hand, the time resource is exclusively `used` by the task that owns it in the `.org` file.

Untracked tasks doues not deserve nor use any time resources.

In the ideal state where (`deserv` == `used`) for all tasks, the time resource is used by all the tasks you've been woking on (`SCHEDULED`), in proportion to their `WEIGHT` in long-time average.


## Background

Getting things done is great way of organizing things, but it lacks a few thing: it doesn't tell you the precise order of doing the tasks. It doesn't tell you how to balance the effort you put into different project.

This is a problem if you have creative tasks in parallel with deadlined tasks. Creative tasks (such as writing programs, research, learning new things, teach students) are hard to estimate for time, since they tend to develop in unexpected ways. On the other hand, the time consumed by deadlined tasks "expands so as to fill the time available for its completion" (Parkinson, 1955). If we allow this to happen, we might end our life meeting deadlines, getting things done, but learning nothing new. We want to avoid this. We would like to finish all deadlined tasks in fraction of the time available, and use the rest of the time in creative projects, in balanced ways.

Dothistroma is a tiny script that helps us do this.


## Acknowledgement

- Dothistroma is still in a very new phase and are welcome for suggestion and improvements.
- I can't thank enough the creators of [Org-mode](http://orgmode.org/), my best planning tool ever. 
- Parnell for writing [Orgmode parser in Hakell](https://github.com/digitalmentat/orgmode-parse).
- I would like to port Dothistroma on elisp (naturally), but I need help on the language. Thanks in advance.
- Dothistroma is named after [Fungi that infect pines](http://en.wikipedia.org/wiki/Dothistroma_septosporum) and pun on "do this".
