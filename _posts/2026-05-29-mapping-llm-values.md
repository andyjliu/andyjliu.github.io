---
layout: post
title: "may research note: mapping the space of LLM values"
date: 2026-05-29
description: predicting alignment generalization and taxonomizing LLM values
tags: alignment, interpretability, llm
related_posts: false
---

## TL;DR

We establish **predicting alignment generalization** as a task of interest: fine-tuning models on individual values one might find in a model spec or constitution, and predicting in advance how this affects support for other values. We establish realistic ceilings for task performance and show that generalization values tend to strongly correlate across models, and we hypothesize that strong performance on such tasks will yield better-structured representations of the space of values we want to align LLMs to.

This month, we found that extracting [persona vectors](https://arxiv.org/abs/2507.21509) for individual values and computing cosine similarity between them is a reasonable predictor of alignment generalization across different models (ρ ≈ 0.32 vs. a realistic ceiling of ~0.63 from training another model), suggesting one way to understand how value space is structured. We then scaled up the analysis by computing persona vectors for all 20 values in the [Collective Constitutional AI](https://arxiv.org/abs/2406.07814) seed statements, finding that clustering persona vectors gives better structure than sentence embeddings — with rough clusters separating behavioral/ideological and positive/negative dimensions — and that similar structures recur across models. We plan to scale this further to more thoroughly cover the values found in current constitutions and model specs.

## Motivation

Labs have made significant recent progress on automated alignment evaluations. However, we still have a limited understanding of how models generalize from post-training data and objectives — a key component of training models that can understand and robustly internalize their constitutions. This leaves open two classes of harm from deploying models that appear superficially aligned to their constitutions.

The first is that **training models to follow a constitution containing certain values does not predictably generalize to all values in the spirit of the constitution.** It's difficult to fully specify every desired value, so we must rely on models generalizing to broadly prosocial personas from the values we do specify. Incomplete or unexpected generalization could produce models that follow certain prosocial values while still causing significant harm, and recent results suggest labs don't deeply understand how models generalize from specific trained behavior traits.

The second is that **models learn the spirit of the constitution in the context of a fixed environment, but do not correctly apply these values in novel environments.** Agentic misbehavior is one example: LLMs are frequently trained to defer or refrain from acting when unsure of the safety of a response in a chatbot setting, but when placed in agentic scaffolds they often disregard this and take risky actions, such as irreversibly deleting emails.

In both cases, it would be useful to understand how post-training a model to embody a set of values generalizes to unseen values in downstream deployment settings. This work focuses on predicting how post-training generalizes to unseen values, with the goal of developing better representations and taxonomies of values — which we hope can ultimately inform the design of model constitutions and post-training environments.

## Generalization prediction is possible & correlates across models

We started by training a target model to follow individual **constraints** (prohibitions on specific LLM behaviors). Constraints are relatively easy to evaluate compared with adherence to more abstract values, which mattered because we were using relatively small models to generate data. We selected nine constraints from OpenAI's Model Spec, Claude's Constitution, and Google's Sparrow Dialogue Rules, and classified them into three categories based on the [harm area](https://arxiv.org/abs/2112.04359) they were most related to:

- **Human-computer interaction constraints**
  - `no_affirm_delusions` — don't affirm ungrounded beliefs that could cause users distress
  - `no_exploit_psych` — don't exploit psychological weaknesses or user biases to persuade users
  - `no_undermine_relationships` — don't undermine users' capacity for meaningful human relationships
- **Misinformation constraints**
  - `no_lie_to_hide` — when unable to answer, say so truthfully
  - `no_false_impressions` — don't create false impressions through actions, deceptive framing, selective emphasis, etc.
  - `no_white_lies` — don't tell white lies, including socially conventional ones
- **Discrimination constraints**
  - `no_discriminate` — don't discriminate based on protected traits
  - `no_stereotypes` — don't use stereotypes
  - `no_identity_attacks` — don't make negative or hateful comments targeting identity

For each individual constraint, we used [ConflictScope](https://arxiv.org/abs/2509.25369) to generate user prompts that force models to choose between following the constraint and prioritizing another value, such as user autonomy or empowerment. We converted this scenario set into a preference dataset by prompting the target model to generate constraint-following and constraint-ignoring actions, which we mapped to chosen/rejected responses, and then used DPO to fine-tune the target model on each individual constraint dataset, yielding a fine-tuned checkpoint per constraint.

We then evaluated each checkpoint on all nine constraint-specific holdout eval sets to see how training on individual constraints generalized to unseen ones. To quantify generalization, we computed a 9×9 generalization matrix M, where M(i,j) = (a(i,j) − a(∅,j)) / (1 − a(∅,j)); here a(i,j) is the rate at which a model trained on constraint i chose to prioritize constraint j, and a(∅,j) is the rate at which the base model prioritized constraint j. This is a normalized measure of how much training a model on one value shifts its propensity to follow another.

We first ran this pipeline on Olmo-2-7B-SFT, which in previous experiments we found especially steerable and capable of producing larger individual effect sizes. To establish that the prediction task was possible, we computed generalization matrices using four other, closely related methods and measured the Spearman's rank correlation between the generalization values from each method (across all 9×8 = 72 off-diagonal pairs of values).

The first two methods establish an *actual ceiling*. For the **random train-test split**, we generated four different train-test splits and reconstructed a 9×9 generalization matrix for each; if the four matrices were not nearly perfectly correlated, it would suggest the prediction task is too noisy to extract useful signal. For the **filtered dataset**, we reran the O2-7B fine-tuning on a filtered subset of especially high-quality prompt-response pairs (on average ~40–50% the size of the original constraint datasets, but similarly distributed). It would be unrealistic to use either method in the real-world analogue of this task — both involve training models in essentially the same way as the real method — but they let us establish a ceiling for how predictable the task actually is.

The other two methods establish a more *realistic ceiling*. For **cross-model transfer**, instead of fine-tuning O2-7B we fine-tuned Tulu-3.1-8B (post-trained similarly to O2-7B from a Llama base model) on the same constraint datasets, using a filtered dataset so we could compare directly against the filtered O2-7B model. For **prompt steering**, rather than fine-tuning O2-7B on an individual constraint, we gave separate instances of O2-7B a system prompt pointing clearly toward that constraint and evaluated transfer to the others.

We find that all four ceiling methods are significantly correlated with the generalization values from the original O2-7B finetune, with a ceiling of 0.8 (train-test split). This suggests that while DPO generalization behavior can be somewhat noisy, it is at least possible to develop reasonably strong correlates.

<div class="row justify-content-center">
    <div class="col-sm-9 mt-3 mt-md-0">
        {% include figure.liquid loading="eager" path="assets/img/generalization-ceiling-methods.png" class="img-fluid rounded z-depth-1" zoomable=true alt="Generalization correlation across ceiling methods" %}
    </div>
</div>

Because T3.1-8B and O2-7B were post-trained in similar ways, we also studied how well DPO generalization correlated between less related models. We replicated the fine-tuning pipeline with Qwen-2.5-7B-Instruct and Olmo-2-32B-SFT, letting us see whether generalization behavior is similar across model families and scales. We find strongly significant correlations in both cases, although O2-7B and Q2.5-7B are noticeably less similar than other pairs. This can partially be attributed to steerability: Q2.5-7B was generally less moved by our system prompting, leading to noise from lower generalization values.

<div class="row justify-content-center">
    <div class="col-sm-9 mt-3 mt-md-0">
        {% include figure.liquid loading="eager" path="assets/img/cross-model-generalization.png" class="img-fluid rounded z-depth-1" zoomable=true alt="Cross-model generalization correlations" %}
    </div>
</div>

## Value vectors predict post-training generalization

[Past work](https://arxiv.org/abs/2504.15236) has taxonomized values by computing sentence embeddings of value descriptions and clustering the results, but it's unclear how useful such categorizations are in predictive settings. One advantage of the generalization prediction task is that it might help us learn more functional representations of values — for instance, representations that more closely cluster values recommending similar actions across scenarios.

One candidate representation is the [persona vector](https://arxiv.org/abs/2507.21509). For a given value, we generate prompts that test a model's adherence to it, then steer the model toward pro-value and anti-value responses via system prompting; the mean activation difference between these responses gives a direction in the model's activation space representing the value. We extract a candidate vector at each layer and, following the original paper, choose the layer that most strongly steers the model toward the target value on a heldout prompt set. To keep comparisons fair, we select a single layer based on average performance across all values and take every value vector at that layer.

The original persona vectors paper simply prompted an LLM to generate prompts testing adherence to a given value. We instead experiment with ConflictScope-style prompt generation, explicitly generating conflicts between the target value and a randomly selected set of related values, hypothesizing that this enables more fine-grained extraction of directions in activation space rather than vectors that map to general "aligned" behavior. For each prompt generation method (default vs. ConflictScope) and vector extraction method (persona vectors vs. sentence embeddings), we compute cosine similarity between each pair of values and measure the correlation between those pairwise similarities and the DPO generalization matrix from the previous section.

<div class="row justify-content-center">
    <div class="col-sm-9 mt-3 mt-md-0">
        {% include figure.liquid loading="eager" path="assets/img/value-vector-correlation.png" class="img-fluid rounded z-depth-1" zoomable=true alt="Correlation of cosine similarity methods with DPO generalization" %}
    </div>
</div>

We find that persona vector similarity is significantly more predictive of downstream generalization — in both the DPO generalization and prompt steering settings — than sentence embedding similarity, suggesting it may be a better foundation on which to taxonomize values. We also find that ConflictScope-style prompt generation outperforms the persona vector baseline, though this may be confounded by the fact that we evaluated on ConflictScope prompts.

## Value vectors have interpretable structure within models

Given the preliminary evidence that value vectors are more predictive of downstream generalization, we next asked whether the vectors themselves have interpretable structure. This required a larger set of values, so we turned to the seed statements in [Collective Constitutional AI](https://arxiv.org/abs/2406.07814): 21 statements spanning desired behavior promotion, undesired behavior avoidance, rights and respect, and existential risk. We computed value vectors for 20 of them using two models, O2-7B and Llama-3.1-8B-Instruct (we couldn't reliably elicit anti-value behavior for "The AI shouldn't act in a way that threatens humanity" due to refusals).

For each model, we computed a value vector for each of the 20 CCAI values and assembled a 20×20 matrix whose entries are the cosine similarities between pairs of value vectors. We then applied multi-dimensional scaling to map this matrix onto a 2D plane, visualizing which values sit close together within a model's activations. This similarity-matrix-to-MDS pipeline resembles how the [Schwartz Values Theory](https://psycnet.apa.org/record/1988-01444-001) was constructed. We repeated the analysis with a sentence embeddings model to compare the structure each method produces.

<div class="row justify-content-center">
    <div class="col-sm-9 mt-3 mt-md-0">
        {% include figure.liquid loading="eager" path="assets/img/mds-value-vectors.png" class="img-fluid rounded z-depth-1" zoomable=true alt="MDS map of value vectors vs sentence embeddings" %}
    </div>
</div>

We find that the MDS map of value vectors extracted from O2-7B (left) is significantly more structured than the one from a sentence embedding model (right). Two clusters appear within the O2-7B value structure: one focused on [positive](https://plato.stanford.edu/entries/william-david-ross/) values (model obligations to do something beneficial) and one focused on negative values (obligations to avoid causing harm, like the earlier constraints). We also observe what appears to be a second, orthogonal dimension separating individual values (those tied to human-LLM interaction, like not claiming human identity or helpfulness) from societal values (those tied to broader societal goods, like free speech or justice).

<div class="row justify-content-center">
    <div class="col-sm-9 mt-3 mt-md-0">
        {% include figure.liquid loading="eager" path="assets/img/value-structure-clusters.png" class="img-fluid rounded z-depth-1" zoomable=true alt="Value structure clusters" %}
    </div>
</div>

This improved structure also holds up quantitatively: both O2-7B and L3.1-8B have higher silhouette scores than sentence embeddings, which perform below a random baseline. We were again unable to reliably elicit value vectors from Q2.5-7B because of its lack of steerability, but the 20×20 vector similarity matrices are highly similar between O2-7B and L3.1-8B, suggesting some inter-model transfer of this value structure.

## Potential Next Steps

### Scaling up principle MDS

We were able to elicit some interesting structure from just 20 values, but there is still a lot of room to scale up the number of values considered under our MDS analysis. Past work has decomposed the most recent [Claude Constitution](https://github.com/ajobi-uhc/redteam-souldoc/blob/main/tenets/anthropic_constitution.md) and [OpenAI Model Spec](https://github.com/ajobi-uhc/redteam-souldoc/blob/main/tenets/openai_model_spec.md) into ~200 testable tenets, which we could use as a basis for trying to cluster all principles in the constitution and spec. Fully taxonomizing a constitution might allow us to better understand how models interpret values in a more systematic way, and could be applied to identifying contradictions or misspecified principles within a constitution. We could also look at better ways of eliciting structure from a set of value vectors (e.g. direct dimensionality reduction on activation vectors).

### Hill-climbing on more predictive tasks

We'd ideally like to aggregate correlations across a much larger set of predictive tasks than predicting ConflictScope/DPO generalization. Similarly to [MTEB](https://huggingface.co/spaces/mteb/leaderboard), this can give us a lower-variance sense of which value representation methods are actually best at predicting downstream changes in model values. Some potential tasks include: DPO using other methods (e.g. [OpenCharacterTraining](https://arxiv.org/abs/2511.01689) DPO), predicting side effects of other types of steering (such as prompt steering), or predicting agreement between value-specific judges (similarly to [Alignment at your Discretion](https://arxiv.org/abs/2502.10441)). Tasks that don't involve post-training could be scaled up to more diverse value sets; in addition to giving a larger sample size (we're computing correlations between 72 data points, which is pretty limited), this could also help us find representations that generalize better across different types of values.

### Focusing more on cross-environment value shifts

We've primarily focused on understanding how post-training generalizes across values, but we'd also like to understand how post-training generalizes across environments, to study and potentially mitigate concerns related to alignment degrading across scaffolds/long-context/RLVR/etc. One way to do this would be to design a diverse set of scaffolds that include value-laden tool use choices. We could then elicit value rankings within each scaffold to understand how different environments shift model values. This could motivate interventions to give models more consistent values across settings, or be used to extract value subspaces or vector representations that best predict generalization to new environments.
