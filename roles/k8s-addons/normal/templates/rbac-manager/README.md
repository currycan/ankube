
# RBAC 管理说明

通过 rbac-manager 可以非常便捷的创建 rbac

- 在创建rbac之前需要创建 webhook admission（kubeconfig），kubeconfig 是不区分 user 和 group

- role/clusterrole 是需要自己手动创建，实现了对资源访问权限的定制，同样不区分 user 和 group

- rolebindings/clusterrolebindings 将 role/clusterrole 中定义的权限授予 user 或 group
