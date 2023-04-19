using Pkg
import XLSX

function get_data(xlsx_file_list)
    Pkg.add("XLSX")
    n = length(xlsx_file_list)
    objects = Vector(undef,n)
    sheets = Vector(undef,n)
    datas = Vector(undef,n)
    for i in eachindex(xlsx_file_list)
        objects[i] = XLSX.readxlsx(xlsx_file_list[i])
        sheets[i] = objects[i][XLSX.sheetnames(objects[i])[1]]
        datas[i] = sheets[i][:]
    end
    return datas    
end

EXCEL_F_NAME_1 = "Dane_PFSP_50_20.xlsx"
EXCEL_F_NAME_2 = "Dane_PFSP_100_10.xlsx"
EXCEL_F_NAME_3 = "Dane_PFSP_200_10.xlsx"

FILES = [EXCEL_F_NAME_1,EXCEL_F_NAME_2,EXCEL_F_NAME_3]

function get_data_values(data)
    result = copy(data)
    for i in 1:length(data)
        m,n = length(result[i][:,1]),length(result[i][1,:])
        result[i] = result[i][2:m,2:n]
    end
    return result
end


function calculateTwoTasks(vec1,vec2)
    n_machines = length(vec1)
    res1 = [0 for i in 1:n_machines]
    res2 = [0 for i in 1:n_machines]
    tmp = 0
    for i in 1:n_machines
        tmp += vec1[i]
        res1[i] = tmp
    end
    res2[1] = vec2[1] + vec1[1]
    for j in 2:n_machines
        if res2[j-1] > res1[j]
            res2[j] = res2[j-1] + vec2[j]
        else 
            res2[j] = res1[j] + vec2[j]
        end
    end
    
    return res2[n_machines]
end


function calculateTasks(data)

    n_machines = length(data[1,:])
    n_tasks = length(data[:,1])
    results = copy(data)
    for i in 1:n_tasks
        for j in 1:n_machines-1
            if i == 1
                if j == 1
                results[1,1] = data[1,1] 
                end
                results[1,j+1] = results[1,j] + data[1,j+1]
            else
                if j == 1      
                    results[i,1] = results[i-1,1] + data[i,1]
                end
                if results[i,j] < results[i-1,j+1]
                    results[i,j+1] = data[i,j+1] + results[i-1,j+1]
                else
                    results[i,j+1] = data[i,j+1] + results[i,j]
                end 
            end
        end
    end
    return results[n_tasks,n_machines]
end

all = get_data(FILES)
datas = get_data_values(all)


function start_best_2_rows(data)
    firstTask = copy(data[1, 1:end])
    secondTask = copy(data[2, 1:end])
    currentTime = calculateTwoTasks(firstTask, secondTask)
    alternativeTime = calculateTwoTasks(secondTask, firstTask)
    seq = [1,2]
    if alternativeTime < currentTime
        ##swap tasks
        temp = copy(data[1,:])
        data[1,:] = copy(data[2,:])
        data[2,:] = temp
        seq = [2,1]
    end
    return data,seq
end


function permutations(beginning)
    n = length(beginning)
    n_correct = n-1 
    mask = [beginning[i] for i in 1:n_correct]
    results = [[0 for i in 1:n] for i in 1:n_correct]
    for i in 1:n_correct
        results[i][i] = beginning[n]
        counter = 1
        for j in 1:n
            if results[i][j] == 0
                results[i][j] = mask[counter]
                counter += 1
            end
        end
    end
    return results
end


function beginnings(current_)
    n = length(current_)
    beginning = [0 for _ in 1:n+1]
    for i in 1:n
        beginning[i] = current_[i]
    end
    beginning[n+1] = n+1
    return beginning
end

function select_best_permutation(permutations,current)
    best_score = calculateTasks(data[current,:])
    best_perm = current
    for perm in permutations
        new_score = calculateTasks(data[perm,:])
        if  new_score < best_score
            best_score = new_score
            best_perm = perm
        end
    end
    return best_perm
end


function NEH(data)
    data,beg = start_best_2_rows(data)
    n = length(data[:,1])
    beginn = [[] for i in 1:n]
    if beg == [2,1]
        beginn[2] = [2,1,3]
    else
        beginn[2] = [1,2,3]
    end
    for i in 2:length(beginn)-1
       permutation = permutations(beginn[i])
       best = select_best_permutation(permutation,beginn[i])
       beginn[i] = best
       beginn[i+1] = beginnings(best)
    end
    return beginn[n-1]
end

data = datas[1]
result = NEH(data)
print(result)
print(calculateTasks(data[result,:]))