---
layout: archive
title: "Research"
permalink: /research/
author_profile: true
---

%% Research

% Computational Language Acquisition with Theory of Mind
Andy Liu, Emmy Liu, Hao Zhu, Yonatan Bisk, Graham Neubig 
*In The Eleventh International Conference on Learning Representations, 2023* [https://arxiv.org/pdf/2303.01502.pdf]([pdf])

% Heterogeneous Topic Interdependencies in Friedkin-Johnsen Models of Opinion Dynamics
Andy Liu, Heather Zinn Brooks
*In preparation*

{% if author.googlescholar %}
  You can also find my articles on <u><a href="{{author.googlescholar}}">my Google Scholar profile</a>.</u>
{% endif %}

{% include base_path %}

{% for post in site.publications reversed %}
  {% include archive-single.html %}
{% endfor %}
