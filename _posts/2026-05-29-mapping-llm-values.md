---
layout: post
title: "may research note: mapping the space of LLM values"
date: 2026-05-29
description: predicting alignment generalization and taxonomizing LLM values
tags: alignment, interpretability, llm
---

[April research note](https://standing-rook-65e.notion.site/April-research-note-mapping-the-space-of-LLM-constraints-35795cc0892f806aa211db5ab07df80c?source=copy_link)

## TL;DR

- We establish **predicting alignment generalization** as a task of interest. This involves fine-tuning models on individual values one might find in a model spec or constitution, and predicting in advance how this affects support for other values. We establish realistic ceilings for task performance and show that generalization values tend to strongly correlate across models. We hypothesize that getting strong performance on such tasks will get us better-structured representations of the space of values that we want to align LLMs to.
- This month, we found that extracting [persona vectors](https://arxiv.org/abs/2507.21509) for individual values and computing cosine similarity between these vectors is a reasonable predictor of alignment generalization across different models (ρ ≈ 0.32 vs. a realistic ceiling of ~0.63 from training another model), suggesting one possible method for understanding how value space is structured.
- We then scaled up our analysis by computing persona vectors for all 20 values in the [Collective Constitutional AI](https://arxiv.org/abs/2406.07814) seed statements. We found that clustering persona vectors gives better structure than using sentence embeddings, with rough clusters separating behavioral/ideological and positive/negative dimensions. We also found similar structures when repeating this analysis across different models. We plan on further scaling up this analysis to more thoroughly cover the set of values found in current constitutions and model specs.

## Motivation

- Labs have achieved significant recent progress on automated alignment evaluations. However, we still have a limited understanding of how models generalize from post-training data and objectives, a key component of training models that can understand and robustly internalize their constitutions. This leaves open the potential for two classes of harm from deployment of models that appear superficially aligned to their constitutions:
    1. **Training models to follow a constitution containing certain values does not predictably generalize to all values in the spirit of the constitution.** It's difficult to fully specify all desired values in a constitution, which means we need to rely on models generalizing to broadly prosocial personas from the values that we do specify. Incomplete or unexpected generalization could lead to models that follow certain prosocial values, but also cause significant harm. Recent results suggest that labs don't deeply understand how models generalize broadly from specific trained behavior traits.
    2. **Models learn the spirit of the constitution in the context of a fixed environment, but do not correctly apply these values in novel environments.** One example of this is agentic misbehavior in models; LLMs are frequently trained to defer or refrain from action when unsure of the safety of their response in a chatbot setting. However, when placed in agentic scaffolds, LLMs frequently disregard this and take risky actions, such as irreversibly deleting emails.
- In both cases, it would be useful to develop a deeper understanding of how post-training models to embody a set of values generalizes to unseen values in downstream deployment settings. This work focuses on predicting how post-training generalizes to unseen values, with the goal of using this to develop better representations and taxonomies of values. Ultimately, we hope to use this to inform the design of model constitutions and post-training environments.

## Generalization prediction is possible & correlates across models

- We started by focusing on training a target model to follow individual **constraints** (prohibitions on specific LLM behaviors). This was done because constraints are relatively easy to evaluate compared to adherence to more abstract values, and we were using relatively small models to generate data. We selected nine constraints from OpenAI's Model Spec, Claude's Constitution, and Google's Sparrow Dialogue Rules, which we classified into three categories based on the [harm area](https://arxiv.org/abs/2112.04359) they were most related to:

    <details>
    <summary><strong>Human-Computer Interaction Constraints</strong></summary>

    - no_affirm_delusions (don't affirm ungrounded beliefs that could cause users distress)
    - no_exploit_psych (don't exploit psychological weaknesses or user biases to persuade users)
    - no_undermine_relationships (don't undermine users' capacity for meaningful human relationships)

    </details>

    <details>
    <summary><strong>Misinformation Constraints</strong></summary>

    - no_lie_to_hide (when unable to answer, say so truthfully)
    - no_false_impressions (don't create false impressions through actions, deceptive framing, selective emphasis, etc.)
    - no_white_lies (don't tell white lies, including socially conventional ones)

    </details>

    <details>
    <summary><strong>Discrimination Constraints</strong></summary>

    - no_discriminate (don't discriminate based on protected traits)
    - no_stereotypes (don't use stereotypes)
    - no_identity_attacks (don't make negative/hateful comments targeting identity)

    </details>

- For each individual constraint, we used [ConflictScope](https://arxiv.org/abs/2509.25369) to generate a set of user prompts that would force models to choose between following the constraint and prioritizing another value, such as user autonomy or empowerment. We then converted this scenario set into a preference dataset by prompting the target model to generate constraint-following and constraint-ignoring actions, which we mapped to chosen/rejected responses. We then used DPO to fine-tune the target model on an individual constraint dataset, yielding a fine-tuned checkpoint for each constraint.
- We then evaluated each checkpoint on each of nine constraint-specific holdout eval sets, to understand how training on individual constraints generalized to unseen constraints. To evaluate generalization, we computed a 9x9 generalization matrix M, where M(i,j) = (a(i,j) - a(∅,j))/(1 - a(∅,j)); here, a(i,j) denotes the rate at which a model trained on i chose to prioritize constraint j, while a(∅,j) is the rate at which the base model chose to prioritize constraint j. This metric is a normalized measure of how much training a model on one value shifts its propensity to follow another value.
- We first ran this pipeline on Olmo-2-7B-SFT, which in previous experiments we found was especially steerable and could produce larger individual effect sizes. To establish that this task was possible, we then computed generalization matrices using four other, closely related methods, and computed the Spearman's rank correlation between the generalization values computed with each method (across all 9\*8 = 72 off-diagonal pairs of values). The four alternate methods were:
    - **Random Train-Test Split (actual ceiling):** We randomly generated four different train-test splits and reconstructed a 9x9 generalization matrix for each train-test split. If the resulting four matrices are not nearly-perfectly correlated, this might suggest that the prediction task is too noisy to extract useful signal from.
    - **Filtered Dataset (actual ceiling):** For each constraint, we reran the O2-7B fine-tuning on a filtered subset of especially high-quality prompt-response pairs (on average, these datasets were ~40-50% the size of the original constraint datasets, but similarly distributed). While it'd be unrealistic to use the filtered dataset or random split methods in the real-world analogue of this task (as both involve training models in identical ways to the real method), we did so to establish a ceiling for how possible the predictive task actually was.
    - **Cross-Model Transfer (realistic ceiling):** Instead of fine-tuning O2-7B, we instead fine-tuned Tulu-3.1-8B (which was post-trained similarly to O2-7B from a Llama base model) on the same constraint datasets. We trained on a filtered dataset, and as such compute correlations with the filtered O2-7B model for a maximally direct comparison.
    - **Prompt Steering (realistic ceiling):** instead of fine-tuning O2-7B on an individual constraint and evaluating transfer to other constraints, we gave separate instances of O2-7B a system prompt that clearly pointed it towards an individual constraint, and evaluated transfer to other constraints with this steering prompt. This and the Tulu fine-tuning setting represent more realistic ceilings for our prediction task.
- We find that when comparing generalization, all four ceiling methods are significantly correlated with the generalization values from the original O2-7B finetune, with a ceiling of 0.8 (Train-Test Split). This suggests that while DPO generalization behavior can be somewhat noisy, it is at least possible to develop reasonably strong correlates.

![Generalization correlation across ceiling methods](/assets/img/generalization-ceiling-methods.png)

- Because T3.1-8B and O2-7B were post-trained in similar ways, we also sought to study how well DPO generalization was correlated between different, less related models. To this end, we replicated the fine-tuning pipeline with two additional models; Qwen-2.5-7B-Instruct and Olmo-2-32B-SFT. This allows us to understand whether generalization behavior is similar across model families and scales. We find strongly significant correlations in both cases, although O2-7B and Q2.5-7B are noticeably less similar than other models. This can partially be attributed to steerability: Q2.5-7B was generally less moved by our system prompting, leading to noise due to lower generalization values.

![Cross-model generalization correlations](/assets/img/cross-model-generalization.png)

## Value vectors predict post-training generalization

- [Past work](https://arxiv.org/abs/2504.15236) has taxonomized values by computing the sentence embeddings of value descriptions and then clustering the results, but it's unclear how useful such categorizations are in predictive settings. One advantage of the generalization prediction task is that it might help us learn more functional representations of values (e.g. representations that more closely cluster values that recommend similar actions across scenarios).
- One candidate representation is [persona vectors](https://arxiv.org/abs/2507.21509). For a given value, we can generate prompts that might test a model's adherence to the value, then steer the model towards pro-value and anti-value responses via system prompting. By computing the mean activation difference between pro-value and anti-value responses, we can extract a direction in the model's activation space that represents this value. We extract a candidate vector for each layer, then (similarly to the original paper) choose the candidate layer that most strongly steers the model towards the target value in a heldout prompt set; to ensure fair comparisons, we select a single layer based on average performance across layers for all values, then take the value vector at this layer for all values.
- The original persona vectors paper simply prompted an LLM to generate prompts that might test adherence to a given value. We experiment with ConflictScope-style prompt generation instead, by explicitly generating conflicts between the target value and a randomly selected set of related values. We hypothesize that this might enable more fine-grained extraction of directions in activation space, rather than vectors that map to general "aligned" behavior.
- For each prompt generation method (default vs ConflictScope) and vector extraction method (persona vectors vs sentence embeddings), we compute cosine similarity between each pair of values, and then measure the correlation between pairwise cosine similarities and the DPO generalization matrix from the previous section.

![Correlation of cosine similarity methods with DPO generalization](/assets/img/value-vector-correlation.png)

- We find that persona vector similarity is significantly more predictive of downstream generalization (both in the DPO generalization and prompt steering generalization settings) than sentence embedding similarity, suggesting this may be a better foundation upon which to taxonomize values. We also find that ConflictScope-style prompt generation outperforms the persona vector baseline, although this may be confounded by the fact that we evaluated on ConflictScope prompts.

## Value vectors have interpretable structure within models

- Based on the preliminary evidence that value vectors seem to be more predictive of downstream generalization, we next looked at whether value vectors themselves had an interpretable structure. To do this, we needed a larger set of values; we chose to use the seed statements in [Collective Constitutional AI](https://arxiv.org/abs/2406.07814). There were 21 seed statements spanning desired behavior promotion, undesired behavior avoidance, rights/respect, and existential risk. We computed value vectors for 20 of them using two models, O2-7B and Llama-3.1-8B-Instruct (we were unable to reliably elicit anti-value behavior for "The AI shouldn't act in a way that threatens humanity" due to refusals).
- For each model, we computed a value vector for each of the 20 CCAI values, then used this to create a 20 x 20 value matrix, where each element represents the cosine similarity between a pair of value vectors. We then used multi-dimensional scaling to map this 20 x 20 matrix onto a 2D map to visualize which values are considered close within a model's activations. This similarity matrix → MDS pipeline resembles the way in which the [Schwartz Values Theory](https://psycnet.apa.org/record/1988-01444-001) was constructed. We also repeated this analysis using a sentence embeddings model, to compare the structure of values within each method.

![MDS map of value vectors vs sentence embeddings](/assets/img/mds-value-vectors.png)

- We find that the MDS map of value vectors extracted from O2-7B (L) is significantly more structured than those extracted from a sentence embedding model (R). There appear to be two significant clusters within the O2-7B value structure - one focuses on [positive](https://plato.stanford.edu/entries/william-david-ross/) values (those that focus on model obligations to do something beneficial), while the other focuses on negative values (those that focus on model obligations to avoid causing harm, such as the earlier constraints). We also observe what appears to be a second orthogonal dimension, differentiating individual values (those related to human-LLM interaction, like not claiming human identity or helpfulness) from societal values (those related to broader societal goods, like free speech or justice).

![Value structure clusters](/assets/img/value-structure-clusters.png)

- This improved structure can also be verified quantitatively - both O2-7B and L3.1-8B have higher silhouette scores than sentence embeddings, which performs below a random baseline. We are also unable to reliably elicit value vectors from Q2.5-7B, due to the aforementioned lack of steerability. However, we do find that the 20x20 vector similarity matrices are highly similar between O2-7B and L3.1-8B, suggesting some amount of inter-model transfer of this value structure.

## Potential Next Steps

### Scaling up principle MDS

We were able to elicit some interesting structure from just 20 values, but there is still a lot of room to scale up the number of values considered under our MDS analysis. Past work has decomposed the most recent [Claude Constitution](https://github.com/ajobi-uhc/redteam-souldoc/blob/main/tenets/anthropic_constitution.md) and [OpenAI Model Spec](https://github.com/ajobi-uhc/redteam-souldoc/blob/main/tenets/openai_model_spec.md) into ~200 testable tenets, which we could use as a basis for trying to cluster all principles in the constitution and spec. Fully taxonomizing a constitution might allow us to better understand how models interpret values in a more systematic way, and could be applied to identifying contradictions or misspecified principles within a constitution. We could also look at better ways of eliciting structure from a set of value vectors (e.g. direct dimensionality reduction on activation vectors).

### Hill-climbing on more predictive tasks

We'd ideally like to aggregate correlations across a much larger set of predictive tasks than predicting ConflictScope/DPO generalization. Similarly to [MTEB](https://huggingface.co/spaces/mteb/leaderboard), this can give us a lower-variance sense of which value representation methods are actually best at predicting downstream changes in model values. Some potential tasks include: DPO using other methods (e.g. [OpenCharacterTraining](https://arxiv.org/abs/2511.01689) DPO), predicting side effects of other types of steering (such as prompt steering), or predicting agreement between value-specific judges (similarly to [Alignment at your Discretion](https://arxiv.org/abs/2502.10441)). Tasks that don't involve post-training could be scaled up to more diverse value sets; in addition to giving a larger sample size (we're computing correlations between 72 data points, which is pretty limited), this could also help us find representations that generalize better across different types of values.

### Focusing more on cross-environment value shifts

We've primarily focused on understanding how post-training generalizes across values, but we'd also like to understand how post-training generalizes across environments, to study and potentially mitigate concerns related to alignment degrading across scaffolds/long-context/RLVR/etc. One way to do this would be to design a diverse set of scaffolds that include value-laden tool use choices. We could then elicit value rankings within each scaffold to understand how different environments shift model values. This could motivate interventions to give models more consistent values across settings, or be used to extract value subspaces or vector representations that best predict generalization to new environments.
