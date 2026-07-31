/// AppUser is a simple model that represents a logged-in user in our app.
/// Instead of using Firebase's full User object everywhere, we create our
/// own small and clean version that only stores the information our app
/// actually needs (uid and email). This makes the app easier to manage and
/// keeps our code organized.
class AppUser {
  final String uid;
  final String email;

  AppUser({required this.uid, required this.email});

  //convert app user to json
  Map<String, dynamic> toJson() {
    return {'uid': uid, 'email': email};
  }

  //convert json to appuser
  factory AppUser.fromJson(Map<String, dynamic> jsonUser) {
    return AppUser(uid: jsonUser['uid'], email: jsonUser['email']);
  }
}
