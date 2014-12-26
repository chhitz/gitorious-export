include FileUtils

def get_output_dir(name)
  File.join(File.dirname(__FILE__), name)
end

def get_project_dir(base, project_name)
  File.join(base, project_name)
end

def get_repo_dir(base, project_name, repo_name)
  File.join(get_project_dir(base, project_name), repo_name)
end

def export_projects_data(projects, output_dir)
  hashed = projects.map do |project|
    repositories = project.repositories.map do |repo|
      {:name => repo.name, :description => repo.description,:owner_type => repo.owner_type, :owner_id => repo.owner_id, :clone_url => repo.clone_url, :committers => repo.committerships.committers.map{|c| c.members.map{|d| d.login}}.flatten}
    end

    {:title => project.title, :owner_type => project.owner_type, :owner_id => project.owner_id, :description => project.description, :slug => project.slug, :repositories => repositories}
  end

  File.open(File.join(output_dir, 'export.json'), 'w'){|f| f.write(hashed.to_json)}
end

def export_projects_source(projects, output_dir)
  projects.each do |project|
    project_dir = get_project_dir(output_dir, project.slug)
    begin
      Dir.mkdir(project_dir)
    end

    puts "#{project.title} cloning #{project.repositories.count}"
    project.repositories.each do |repo|
      project_dir = get_project_dir(output_dir, project.slug)
      Dir.chdir(project_dir) do
        begin
          Dir.chdir(repo.name) do
            puts "  update #{repo.name}"
            `git pull`
          end
        rescue
          puts "  cloning #{repo.name} (#{repo.full_repository_path} => #{repo.name})"
          `git clone --bare #{repo.full_repository_path} #{repo.name}.git`
          begin
            empty = Dir.chdir(repo.name) do
              num_refs = `git count-objects | cut -c 1`
              num_refs == '0'
            end
            rm_rf repo.name if empty
          rescue
	    puts "  #{repo.name} was not cloned"
          end
        end
      end
    end
  end
end

def export_projects(projects, output_dir)
  export_projects_data(projects, output_dir)
  export_projects_source(projects, output_dir)
end

def export_users(users, output_dir)
  user_hashed = users.map do |user|
    {:login => user.login, :email => user.email, :ssh_keys => user.ssh_keys.map{|k| k.key}}
  end

  File.open(File.join(output_dir, 'users.json'), 'w'){|f| f.write(user_hashed.to_json)}
end

def export_groups(groups, output_dir)
  group_hashed = groups.map do |group|
    {:name => group.name, :description => group.description, :members => group.members.map{|u| u.login}}
  end

  File.open(File.join(output_dir, 'groups.json'), 'w'){|f| f.write(group_hashed.to_json)}
end

output_dir = get_output_dir(File.join('..', 'output'))

#rm_rf(output_dir) if File.directory?(output_dir)
begin
  Dir.mkdir(output_dir)
end

projects = Project.all

export_projects(projects, output_dir)
export_users(User.all, output_dir)
export_groups(Group.all, output_dir)

