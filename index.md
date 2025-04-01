---
layout: default
title: Home
---

<h1>🏡 Welcome to My Blog!</h1>

<h2>📜 Recent Posts:</h2>
<ul>
  {% for post in site.posts %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date: "%B %d, %Y" }})</li>
  {% endfor %}
</ul>

## 📜 Posts by Category:
{% assign categories = site.posts | group_by: "categories" %}
{% for category in categories %}
### {{ category.name | capitalize }}
<ul>
  {% for post in category.items %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date: "%B %d, %Y" }})</li>
  {% endfor %}
</ul>
{% endfor %}
