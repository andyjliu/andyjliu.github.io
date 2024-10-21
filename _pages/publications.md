---
layout: archive
title: "Publications"
permalink: /publications/
author_profile: true
---
## Evaluating Large Language Model Biases in Persona-Steered Generation
Andy Liu, Mona Diab, Daniel Fried

*In Findings of the Association for Computational Linguistics: ACL 2024.*
[[pdf]](https://arxiv.org/pdf/2405.20253.pdf) 
[[code]](https://github.com/andyjliu/persona-steered-generation-bias)

We study the task of persona-steered text generation, where models must generate text that reflects the distribution of views that an individual fitting a persona could have. We find models are worse at representing multifaceted personas whose dimensions are incongruous with each other, and that preference-based fine-tuning improves LLM steerability at the cost of diversity.


## Computational Language Acquisition with Theory of Mind
Andy Liu, Emmy Liu, Hao Zhu, Yonatan Bisk, Graham Neubig 

*In The Eleventh International Conference on Learning Representations, 2023.* [[pdf]](https://arxiv.org/pdf/2303.01502.pdf) [[code]](https://github.com/neulab/ToM-Language-Acquisition)

We equip language-learning agents with theory of mind, operationalized as an internal model of a teacher agent that is trained alongside the learner. We find that both including ToM and increasing environment difficulty lead to improved language acquisition in an image referential game setting.

## BIG5-CHAT: Shaping LLM Personalities Through Training on Human-Grounded Data
Wenkai Li*, Jiarui Liu*, **Andy Liu**, Xuhui Zhou, Mona Diab, Maarten Sap

*Arxiv Preprint.* [pdf] [code]

We create a large-scale, human-grounded dialogue dataset that shows how social media users express their personality in text. We then align language models to various personality traits, finding that our methods outperform prompting on personality assessments and lead to models with similar trait-ability correlations to human studies on downstream tasks.


{% if author.googlescholar %}
  You can also find my articles on <u><a href="{{author.googlescholar}}">my Google Scholar profile</a>.</u>
{% endif %}

{% include base_path %}
