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
