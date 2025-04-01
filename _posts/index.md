---
layout: default
title: Home
---

# 🏡 Welcome to My Blog!

## 📜 Recent Posts:
<ul>
  {% for post in site.posts %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date: "%B %d, %Y" }})</li>
  {% endfor %}
</ul>
