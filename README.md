collision-tests
===============

This began as an attempt to hammer out a stable collision setup in 2D, with the aim of then
translating the results to a top-down situation. A few folders even have a **topdown.lua**
that plays around with this at a very basic level.

The approach described [here](http://www.peroxide.dk/download/tutorials/tut10/pxdtut10.html)
was basically my point of departure.

It began with a box as the "character". There are commented-out hints of this in the code, but
I don't remember if merely changing that would be enough to go back to that. This project has
been shuttled around on Dropbox and USB sticks, rather than Git, and I've forgotten the finer
points of its history, including the **updated** subfolders and what those mean versus their
parent directories, along with the **sidescroller** / **sidescroller1** distinction.

So you're a circle now.

Roughly, I believe the first test is the raw Lua version. You can move around with the left and
right cursor keys, and jump with the up key, and for the most part interactions seem to work well.

With test #2, I moved some of the collision into a [native plugin](https://github.com/ggcrunchy/solar2d-plugins/tree/master/collision_test_native),
not so much due to any demand for speed, but rather to play with features that were new to Solar
at the time, like the `Solar2DPlugins` directory. Content-wise I don't think this differs much.

Test #3 is basically an attempt to port these to Solar's Box2D-based `physics` module, using
something of a joint-based unicycle approach. I'm sure I could improve it significantly, but so
far I haven't like this version much. It's required considerable fine-tuning and still doesn't
feel to me anywhere near as tight as the others.

Lastly, **3dish** is only barely related, using the collision plugin. It emulates a little 2.5D
scene&mdash;limiting the camera POV to do so&mdash;and performs a collision of a falling sphere
with a slope.

I'm not sure what the status of the originally intended top-down project is, but I have given a
lot of thought to making some side-scroller with test #2 as a starting point.
