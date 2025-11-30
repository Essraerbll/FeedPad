import 'package:flutter/material.dart';

class FeedBlogScreen extends StatelessWidget {
  const FeedBlogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'FeedBlog',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ),
    );
  }
}
